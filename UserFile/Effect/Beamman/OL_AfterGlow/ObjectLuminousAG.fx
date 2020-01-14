//元ソース：ObjectLuminous.fx
//改変：ビームマンP


////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

//残光係数
float AfterGlow
<
   string UIName = "AfterGlow";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.9 );

// ぼかし範囲 (サンプリング数は固定のため、大きくしすぎると縞が出ます) 
// にじみ
float Extent_S
<
   string UIName = "Extent_S";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 0.01;
> = float( 0.001 );

// ガウス
float Extent_G
<
   string UIName = "Extent_G";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.00;
   float UIMax = 0.01;
> = float( 0.001 );

//発光強度
float Strength_A
<
   string UIName = "Strength_A";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 5.0 );

float Strength_B
<
   string UIName = "Strength_B";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 10.0;
> = float( 5 );


//点滅周期、単位：フレーム、0で停止
int Interval
<
   string UIName = "Interval";
   string UIWidget = "Numeric";
   bool UIVisible =  true;
   int UIMin = 0;
   int UIMax = 300;
> = 0;

//編集中の点滅をフレーム数に同期
#define SYNC false


///////////////////////////////////////////////////////////////////////////////////////////////
// 光放射オブジェクト描画先

texture OL_EmitterRT: OFFSCREENRENDERTARGET <
    string Description = "EmitterDrawRenderTarget for ObjectLuminousAG.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "*Luminous.fx = hide;"
        "* = OL_BlackMask.fx;" 
    ;
>;

sampler EmitterView = sampler_state {
    texture = <OL_EmitterRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
///////////////////////////////////////////////////////////////////////////////////////////////
// ビームマン追加：1F前のバッファ

texture2D EmitterPrev : RENDERCOLORTARGET <
    float2 ViewPortRatio = {0.5,0.5};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D PrevView = sampler_state {
    texture = <EmitterPrev>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
////////////////////////////////////////////////////////////////////////////////////////////////

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0〜7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379

#define PI 3.14159

const float4 Color_Black = {0,0,0,1};
const float4 Color_White = {1,1,1,1};


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// マテリアル色
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;
//スケール
float4x4 WorldMatrix : WORLD;
static float scaling = length(WorldMatrix._11_12_13) * 0.1;

//時間
float ftime : TIME <bool SyncInEditMode = SYNC;>;
static float timerate = Interval ? ((1 + cos(ftime * 2 * PI * 30 / (float)Interval)) * 0.4 + 0.2) : 1.0;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);

static float2 SampStep = (float2(Extent_G,Extent_G)/ViewportSize*ViewportSize.y);
static float2 SampStep2 = (float2(Extent_S,Extent_S)/ViewportSize*ViewportSize.y);


// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,1};
float4 ClearColorTr = {0,0,0,0};
float ClearDepth  = 1.0;

////////////////////////////////////////////////////////////////////////////////////
// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

///////////////////////////////////////////////////////////////////////////////////////////////

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX : RENDERCOLORTARGET <
    float2 ViewPortRatio = {0.5,0.5};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSampX = sampler_state {
    texture = <ScnMapX>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapY : RENDERCOLORTARGET <
    float2 ViewPortRatio = {0.5,0.5};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSampY = sampler_state {
    texture = <ScnMapY>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 白とび表現関数
float4 OverExposure(float4 color){
    float4 newcolor = color;
    
    //ある色が1を超えると、他の色にあふれる
    newcolor.gb += saturate(color.r - 1);
    newcolor.rb += saturate(color.g - 1);
    newcolor.rg += saturate(color.b - 1);
    
    return saturate(newcolor);
}


////////////////////////////////////////////////////////////////////////////////////////////////
//共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);
    
    return Out;
}

VS_OUTPUT VS_passDraw2( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x * 2, ViewportOffset.y * 2);
    
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ファーストパス

float4 PS_first( float2 Tex: TEXCOORD0 ) : COLOR {
    float4 Color;
    
    //オフスクリーンターゲットより読み込み、軽いぼかし
    Color = tex2D( EmitterView, Tex ) * 2;
    Color += tex2D( EmitterView, Tex + float2(0, OnePx.y) );
    Color += tex2D( EmitterView, Tex + float2(0, -OnePx.y) );
    Color += tex2D( EmitterView, Tex + float2(OnePx.x, 0) );
    Color += tex2D( EmitterView, Tex + float2(OnePx.x, OnePx.y) );
    Color += tex2D( EmitterView, Tex + float2(OnePx.x, -OnePx.y) );
    Color += tex2D( EmitterView, Tex + float2(-OnePx.x, 0) );
    Color += tex2D( EmitterView, Tex + float2(-OnePx.x, OnePx.y) );
    Color += tex2D( EmitterView, Tex + float2(-OnePx.x, -OnePx.y) );
    
    Color /= 10;
    
    //ビームマン追加
    //残光を考慮して元色を薄くする
    Color *= 1-AfterGlow;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向にじみ

float4 PS_passSX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    float step = SampStep2.x * scaling * timerate;
    
    Color = tex2D( ScnSampY, Tex );
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSampY, Tex+float2(step     ,0)));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSampY, Tex+float2(step * 2 ,0)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSampY, Tex+float2(step * 3 ,0)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSampY, Tex+float2(step * 4 ,0)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSampY, Tex+float2(step * 5 ,0)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSampY, Tex+float2(step * 6 ,0)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSampY, Tex+float2(step * 7 ,0)));
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSampY, Tex-float2(step     ,0)));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSampY, Tex-float2(step * 2 ,0)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSampY, Tex-float2(step * 3 ,0)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSampY, Tex-float2(step * 4 ,0)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSampY, Tex-float2(step * 5 ,0)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSampY, Tex-float2(step * 6 ,0)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSampY, Tex-float2(step * 7 ,0)));
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向にじみ

float4 PS_passSY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float step = SampStep2.y * scaling * timerate;
    
    Color = tex2D( ScnSampX, Tex );
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSampX, Tex+float2(0, step    )));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSampX, Tex+float2(0, step * 2)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSampX, Tex+float2(0, step * 3)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSampX, Tex+float2(0, step * 4)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSampX, Tex+float2(0, step * 5)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSampX, Tex+float2(0, step * 6)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSampX, Tex+float2(0, step * 7)));
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSampX, Tex-float2(0, step    )));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSampX, Tex-float2(0, step * 2)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSampX, Tex-float2(0, step * 3)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSampX, Tex-float2(0, step * 4)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSampX, Tex-float2(0, step * 5)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSampX, Tex-float2(0, step * 6)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSampX, Tex-float2(0, step * 7)));
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    float step = SampStep.x * scaling * timerate;
    
    Color  = WT_0 *   tex2D( ScnSampY, Tex );
    Color.rgb *= Strength_A;
    Color = OverExposure(Color);
    
    Color += WT_1 * ( tex2D( ScnSampY, Tex+float2(step    ,0) ) + tex2D( ScnSampY, Tex-float2(step    ,0) ) );
    Color += WT_2 * ( tex2D( ScnSampY, Tex+float2(step * 2,0) ) + tex2D( ScnSampY, Tex-float2(step * 2,0) ) );
    Color += WT_3 * ( tex2D( ScnSampY, Tex+float2(step * 3,0) ) + tex2D( ScnSampY, Tex-float2(step * 3,0) ) );
    Color += WT_4 * ( tex2D( ScnSampY, Tex+float2(step * 4,0) ) + tex2D( ScnSampY, Tex-float2(step * 4,0) ) );
    Color += WT_5 * ( tex2D( ScnSampY, Tex+float2(step * 5,0) ) + tex2D( ScnSampY, Tex-float2(step * 5,0) ) );
    Color += WT_6 * ( tex2D( ScnSampY, Tex+float2(step * 6,0) ) + tex2D( ScnSampY, Tex-float2(step * 6,0) ) );
    Color += WT_7 * ( tex2D( ScnSampY, Tex+float2(step * 7,0) ) + tex2D( ScnSampY, Tex-float2(step * 7,0) ) );
    
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float4 MaskColor;
    float step = SampStep.y * scaling * timerate;
    
    
    Color  = WT_0 *   tex2D( ScnSampX, Tex );
    Color += WT_1 * ( tex2D( ScnSampX, Tex+float2(0,step    ) ) + tex2D( ScnSampX, Tex-float2(0,step    ) ) );
    Color += WT_2 * ( tex2D( ScnSampX, Tex+float2(0,step * 2) ) + tex2D( ScnSampX, Tex-float2(0,step * 2) ) );
    Color += WT_3 * ( tex2D( ScnSampX, Tex+float2(0,step * 3) ) + tex2D( ScnSampX, Tex-float2(0,step * 3) ) );
    Color += WT_4 * ( tex2D( ScnSampX, Tex+float2(0,step * 4) ) + tex2D( ScnSampX, Tex-float2(0,step * 4) ) );
    Color += WT_5 * ( tex2D( ScnSampX, Tex+float2(0,step * 5) ) + tex2D( ScnSampX, Tex-float2(0,step * 5) ) );
    Color += WT_6 * ( tex2D( ScnSampX, Tex+float2(0,step * 6) ) + tex2D( ScnSampX, Tex-float2(0,step * 6) ) );
    Color += WT_7 * ( tex2D( ScnSampX, Tex+float2(0,step * 7) ) + tex2D( ScnSampX, Tex-float2(0,step * 7) ) );
    
    Color.rgb *= (Strength_B * alpha1 * timerate);
    Color = OverExposure(Color);
    
    //ブロック領域の適用
    MaskColor = tex2D( EmitterView, Tex );
    Color.rgb *= MaskColor.a;
    Color.a = 1;//MaskColor.a;
    
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// ビームマン追加：バッファに光をコピー

float4 PS_passBuffCpy(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color = tex2D( PrevView, Tex )*AfterGlow;
    Color-=0.005;
    Color += tex2D( ScnSampY, Tex );
    Color = saturate(Color);
    
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// ビームマン追加：メイン画面に光を張り付け

float4 PS_passMix(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    Color = tex2D( PrevView, Tex );
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック・6パスも必要・・・
//ビームマン追記：さらにパス追加・・・

technique ObjectLuminous <
    string Script = 
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "ScriptExternal=Color;"
        
        "RenderColorTarget0=ScnMapY;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=FirstPass;"
        
        "RenderColorTarget0=ScnMapX;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Spread_X;"
        
        "RenderColorTarget0=ScnMapY;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Spread_Y;"
        
        "RenderColorTarget0=ScnMapX;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Gaussian_X;"
        
        "RenderColorTarget0=ScnMapY;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Gaussian_Y;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Pass=Mix;"
        
        "RenderColorTarget0=EmitterPrev;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "Pass=BuffCpy;"

    ;
    
> {
    
    pass FirstPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_first();
    }
    pass Spread_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw2();
        PixelShader  = compile ps_2_0 PS_passSX();
    }
    pass Spread_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw2();
        PixelShader  = compile ps_2_0 PS_passSY();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw2();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw2();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass Mix < string Script= "Draw=Buffer;"; > {
        SRCBLEND = ONE;
        DESTBLEND = ONE;
        VertexShader = compile vs_2_0 VS_passDraw2();
        PixelShader  = compile ps_2_0 PS_passMix();
    }
    //ビームマン追加：バッファにコピー
    pass BuffCpy < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw2();
        PixelShader  = compile ps_2_0 PS_passBuffCpy();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////



