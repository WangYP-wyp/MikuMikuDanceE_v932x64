////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Post_ScreenTex.fx ver0.0.4  �e�N�X�`������ʃT�C�Y�ɃX�P�[�����O���ē\��t���܂�(�|�X�g�G�t�F�N�gver)
//  �쐬: �j��P( ���͉��P����Gaussian.fx���� )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// �����̃p�����[�^��ύX���Ă�������
#define UseTex  1                   // 1:�e�N�X�`��, 2:�A�j��GIF�APNG, 3:Screen.bmp�A�j��
#define TexFile "sen.png"        // ��ʂɓ\��t����e�N�X�`���t�@�C����
#define AnimeStart 0.0              // �A�j��GIF�APNG�̏ꍇ�̃A�j���[�V�����J�n����(�P�ʁF�b)(�A�j��GIF�APNG�ȊO�ł͖���)


// ����Ȃ��l�͂������牺�͂�����Ȃ��ł�
////////////////////////////////////////////////////////////////////////////////////////////////

// MMM UI�R���g���[��
float3 MMMColorKey <      // �J���[�L�[�̐F(RGB�w��)
   string UIName = "�J���[�L�[�̐F";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(0.0, 0.0, 0.0);

float MMMThreshold <   // �J���[�L�[��臒l
   string UIName = "�L�[臒l";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.0 );


// �A�N�Z�T���p�����[�^
float3 AcsOffset : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float AcsR : CONTROLOBJECT < string name = "(self)"; string item = "Rx"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
static float3 ColorKey = saturate( AcsOffset );             // �J���[�L�[�̐F(RGB�w��)
static float Threshold = saturate( degrees(AcsR) ) - 0.01f; // �J���[�L�[��臒l

// �X�N���[���T�C�Y
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;

// �����_�����O�^�[�Q�b�g�̃N���A�l
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

#if(UseTex == 1)
// ��ʂɓ\��t����e�N�X�`��
texture2D screen_tex <
    string ResourceName = TexFile;
>;
sampler TexSampler = sampler_state {
    texture = <screen_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif

#if(UseTex == 2)
// ��ʂɓ\��t����A�j���[�V�����e�N�X�`��
texture screen_tex : ANIMATEDTEXTURE <
    string ResourceName = TexFile;
    float Offset = AnimeStart;
>;
sampler TexSampler = sampler_state {
    texture = <screen_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif

#if(UseTex == 3)
// �I�u�W�F�N�g�̃e�N�X�`��
texture ObjectTexture: MATERIALTEXTURE;
sampler TexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// ��ʕ`��

struct VS_OUTPUT {
    float4 Pos			: POSITION;
    float2 Tex			: TEXCOORD0;
};

// ���_�V�F�[�_
VS_OUTPUT VS_ScreenTex( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// �s�N�Z���V�F�[�_
float4 PS_ScreenTex( float2 Tex: TEXCOORD0 ) : COLOR
{
    // �e�N�X�`���K�p
    float4 Color = tex2D( TexSampler, Tex );

    if((Threshold + MMMThreshold) > 0.0f){
       // �J���[�L�[����
       float len = length(Color.rgb - saturate(ColorKey+MMMColorKey));
       if( len <= (Threshold + MMMThreshold) ) Color.a = 0;
    }
    Color.a *= AcsTr;

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique ScreenTexTech <
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color; Clear=Depth;"
            "ScriptExternal=Color;"
	    "Pass=ScreenTexPass;"
    ;
> {
    pass ScreenTexPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_ScreenTex();
        PixelShader  = compile ps_2_0 PS_ScreenTex();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
