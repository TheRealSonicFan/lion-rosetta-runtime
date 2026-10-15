#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/stat.h>

#define BUILD_ID "coreui-windowframe-shared-art-slot0-compat-v1"
#define BUILD_MARKER "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:" BUILD_ID "\n"
#define MODE_ENV "ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_MODE"
#define MODE_PASSTHROUGH "snow-passthrough-v1"
#define MODE_LION "lion-bitmapinfo-0x2002-v1"
#define COREUI_TOKEN "/CoreUI.framework/"
#define COREUI_ARTFILE_RETURN_OFFSET 0x000299e0U
#define COREUI_SHARED_RAW_IMAGE_RETURN_OFFSET 0x0002ad34U
#define COREUI_SHARED_IMAGEIO_SOURCE_RETURN_OFFSET 0x0002ae28U
#define COREUI_SHARED_IMAGEIO_FINAL_RETURN_OFFSET 0x0002afe8U
#define COREUI_SHARED_RAW_SAVED_R30_OFFSET 0x00000068U
#define COREUI_SHARED_IMAGEIO_SOURCE_SAVED_R30_OFFSET 0x00000058U
#define SART_PATH "/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/SArtFile.bin"
#define SART_SIZE 9370228U
#define SART_VERSION 2U
#define SART_COUNT 348U
#define SART_DATA_BASE 0x00003ff0U
#define SART_TABLE_BASE 0x00000008U
#define SART_IMAGE_BASE 0x00004e20U
#define SLOT0_WIDTH 11U
#define SLOT0_HEIGHT 11U
#define SLOT0_BPR 44U
#define SLOT0_LENGTH 484U
#define SNOW_WIDTH 14U
#define SNOW_HEIGHT 16U
#define SNOW_BPR 56U
#define LION_WIDTH 16U
#define LION_HEIGHT 16U
#define LION_BPR 64U
#define BPC 8U
#define BPP 32U
#define SNOW_BITMAP_INFO 0x00000002U
#define LION_BITMAP_INFO 0x00002002U
#define MAX_BINDINGS 16U

struct frame_map { uint32_t legacy_id, lion_id, header_off, slot0_rel; };
static const struct frame_map gFrameMap[] = {
    {0x00004e8dU,0x00004e75U,0x00001488U,0x001ebffcU},
    {0x00004e8eU,0x00004e76U,0x000014acU,0x001ec970U},
    {0x00004e8fU,0x00004e77U,0x000014d0U,0x001ed2e4U},
    {0x00004e90U,0x00004e78U,0x000014f4U,0x001edc58U},
    {0x00004e91U,0x00004e79U,0x00001518U,0x001ee5ccU}
};
#define FRAME_MAP_COUNT ((unsigned int)(sizeof(gFrameMap)/sizeof(gFrameMap[0])))

typedef CGDataProviderRef (*provider_fn)(void *, const void *, size_t, CGDataProviderReleaseDataCallback);
typedef CGImageRef (*image_fn)(size_t,size_t,size_t,size_t,size_t,CGColorSpaceRef,CGBitmapInfo,CGDataProviderRef,const CGFloat *,bool,CGColorRenderingIntent);
typedef CGImageSourceRef (*source_fn)(CGDataProviderRef, CFDictionaryRef);
typedef CGImageRef (*source_image_fn)(CGImageSourceRef, size_t, CFDictionaryRef);
struct interpose_tuple { const void *replacement; const void *replacee; };
static struct interpose_tuple sProviderInterpose, sImageInterpose, sSourceInterpose, sSourceImageInterpose;
static provider_fn gProviderOriginal;
static image_fn gImageOriginal;
static source_fn gSourceOriginal;
static source_image_fn gSourceImageOriginal;
static int gBuildLogged;
static unsigned int gCompatCallIndex;
static pthread_mutex_t gLock = PTHREAD_MUTEX_INITIALIZER;
static const unsigned char *gSArt;
static size_t gSArtSize;
static int gSArtState;
struct source_binding { CGImageSourceRef source; uint32_t legacy_id; };
static struct source_binding gBindings[MAX_BINDINGS];

#define READ_CALLER_SAVED_U32(stack_offset, out_value, out_ok) do { \
    uintptr_t _sp=(uintptr_t)__builtin_frame_address(0), _caller_sp=0; \
    if (_sp!=0) _caller_sp=*(const volatile uintptr_t *)(uintptr_t)_sp; \
    if (_caller_sp!=0) { (out_value)=*(const volatile uint32_t *)(uintptr_t)(_caller_sp+(stack_offset)); (out_ok)=1; } \
    else { (out_value)=0; (out_ok)=0; } \
} while (0)

static void write_literal(const char *s){size_t n=strlen(s);while(n){ssize_t w=write(STDERR_FILENO,s,n);if(w<=0)return;s+=w;n-=(size_t)w;}}
static void log_build_once(void){if(!gBuildLogged){write_literal(BUILD_MARKER);gBuildLogged=1;}}
static void append_text(char *b,size_t c,size_t *p,const char *s){size_t n=strlen(s);if(*p+n>=c)return;memcpy(b+*p,s,n);*p+=n;}
static void append_uint(char *b,size_t c,size_t *p,unsigned long v){char t[32];unsigned int n=0,i;if(!v){if(*p+1<c)b[(*p)++]='0';return;}while(v&&n<sizeof(t)){t[n++]=(char)('0'+v%10UL);v/=10UL;}for(i=0;i<n;i++){if(*p+1>=c)return;b[(*p)++]=t[n-1-i];}}
static void append_hex32(char *b,size_t c,size_t *p,uint32_t v){static const char d[]="0123456789abcdef";int s;append_text(b,c,p,"0x");for(s=28;s>=0;s-=4){if(*p+1>=c)return;b[(*p)++]=d[(v>>s)&15U];}}
static int mode_lion(void){const char *m=getenv(MODE_ENV);return m&&strcmp(m,MODE_LION)==0;}
static int raw_target_geometry(uint32_t id,size_t w,size_t h,size_t bpr){if(id==0x00004e8eU)return w==256U&&h==256U&&bpr==1024U;if(id==0x00004e8dU)return w==2U&&h==62U&&bpr==8U;return 0;}
static int imageio_target(uint32_t id){return id==0x00004e90U||id==0x00004e8fU||id==0x00004e91U;}
static int mode_valid(const char **out){const char *m=getenv(MODE_ENV);if(out)*out=m?m:"UNSET";return m&&(strcmp(m,MODE_PASSTHROUGH)==0||strcmp(m,MODE_LION)==0);}
static int caller_info(const void *caller,uint32_t *off){Dl_info i;uintptr_t a=(uintptr_t)caller,b;if(off)*off=0;memset(&i,0,sizeof(i));if(!caller||dladdr(caller,&i)==0||!i.dli_fname||!i.dli_fbase)return 0;if(!strstr(i.dli_fname,COREUI_TOKEN))return 0;b=(uintptr_t)i.dli_fbase;if(a<b)return 0;if(off)*off=(uint32_t)(a-b);return 1;}
static uint16_t le16(const unsigned char *p){return (uint16_t)(p[0]|((uint16_t)p[1]<<8));}
static uint32_t le32(const unsigned char *p){return (uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static const struct frame_map *find_map(uint32_t legacy){unsigned int i;for(i=0;i<FRAME_MAP_COUNT;i++)if(gFrameMap[i].legacy_id==legacy)return &gFrameMap[i];return NULL;}
static int validate_record(const unsigned char *base,const struct frame_map *m){uint32_t idx=m->lion_id-SART_IMAGE_BASE,table=SART_TABLE_BASE+idx*4U,h;if(table+4U>SART_SIZE)return 0;h=le32(base+table);if(h!=m->header_off||h+0x18U>SART_SIZE)return 0;if(le16(base+h)!=1U||le16(base+h+2U)!=2U)return 0;if(le16(base+h+0x0cU)!=SLOT0_WIDTH||le16(base+h+0x0eU)!=SLOT0_HEIGHT)return 0;if(le32(base+h+0x10U)!=SLOT0_LENGTH||le32(base+h+0x14U)!=m->slot0_rel)return 0;if(SART_DATA_BASE+m->slot0_rel+SLOT0_LENGTH>SART_SIZE)return 0;return 1;}
static int ensure_sart(void){int fd=-1,ok=0;struct stat st;void *p=MAP_FAILED;unsigned int i;pthread_mutex_lock(&gLock);if(gSArtState!=0){ok=(gSArtState>0);pthread_mutex_unlock(&gLock);return ok;}fd=open(SART_PATH,O_RDONLY);if(fd<0)goto done;if(fstat(fd,&st)!=0||(size_t)st.st_size!=SART_SIZE)goto done;p=mmap(NULL,SART_SIZE,PROT_READ,MAP_PRIVATE,fd,0);if(p==MAP_FAILED)goto done;if(le16((const unsigned char *)p)!=SART_VERSION||le16((const unsigned char *)p+2U)!=SART_COUNT||le32((const unsigned char *)p+4U)!=SART_DATA_BASE)goto done;for(i=0;i<FRAME_MAP_COUNT;i++)if(!validate_record((const unsigned char *)p,&gFrameMap[i]))goto done;gSArt=(const unsigned char *)p;gSArtSize=SART_SIZE;gSArtState=1;ok=1;p=MAP_FAILED;done:if(fd>=0)close(fd);if(p!=MAP_FAILED)munmap(p,SART_SIZE);if(!ok)gSArtState=-1;pthread_mutex_unlock(&gLock);return ok;}
static const void *mapped_slot0(uint32_t legacy,uint32_t *lion){const struct frame_map *m=find_map(legacy);if(!m||!ensure_sart())return NULL;if(lion)*lion=m->lion_id;return gSArt+SART_DATA_BASE+m->slot0_rel;}
static provider_fn provider_original(void){if(!gProviderOriginal)gProviderOriginal=(provider_fn)(uintptr_t)sProviderInterpose.replacee;return gProviderOriginal;}
static image_fn image_original(void){if(!gImageOriginal)gImageOriginal=(image_fn)(uintptr_t)sImageInterpose.replacee;return gImageOriginal;}
static source_fn source_original(void){if(!gSourceOriginal)gSourceOriginal=(source_fn)(uintptr_t)sSourceInterpose.replacee;return gSourceOriginal;}
static source_image_fn source_image_original(void){if(!gSourceImageOriginal)gSourceImageOriginal=(source_image_fn)(uintptr_t)sSourceImageInterpose.replacee;return gSourceImageOriginal;}
static CGImageRef create_slot0(uint32_t legacy,CGColorSpaceRef space,uint32_t *lion){const void *data;CGDataProviderRef p;CGImageRef im;provider_fn pf=provider_original();image_fn imf=image_original();if(!pf||!imf||!space)return NULL;data=mapped_slot0(legacy,lion);if(!data)return NULL;p=pf(NULL,data,SLOT0_LENGTH,NULL);if(!p)return NULL;im=imf(SLOT0_WIDTH,SLOT0_HEIGHT,BPC,BPP,SLOT0_BPR,space,(CGBitmapInfo)SNOW_BITMAP_INFO,p,NULL,true,kCGRenderingIntentDefault);CGDataProviderRelease(p);return im;}
static void bind_source(CGImageSourceRef s,uint32_t id){unsigned int i,free_i=MAX_BINDINGS;pthread_mutex_lock(&gLock);for(i=0;i<MAX_BINDINGS;i++){if(gBindings[i].source==s){gBindings[i].legacy_id=id;pthread_mutex_unlock(&gLock);return;}if(!gBindings[i].source&&free_i==MAX_BINDINGS)free_i=i;}if(free_i<MAX_BINDINGS){gBindings[free_i].source=s;gBindings[free_i].legacy_id=id;}pthread_mutex_unlock(&gLock);}
static uint32_t take_source(CGImageSourceRef s){unsigned int i;uint32_t id=0;pthread_mutex_lock(&gLock);for(i=0;i<MAX_BINDINGS;i++)if(gBindings[i].source==s){id=gBindings[i].legacy_id;gBindings[i].source=NULL;gBindings[i].legacy_id=0;break;}pthread_mutex_unlock(&gLock);return id;}
static void log_slot0(const char *phase,const char *branch,uint32_t legacy,uint32_t lion,const char *result){char b[384];size_t p=0;log_build_once();append_text(b,sizeof(b),&p,"PM_COREUI_SHARED_ART_SLOT0_COMPAT:");append_text(b,sizeof(b),&p,phase);append_text(b,sizeof(b),&p," branch=");append_text(b,sizeof(b),&p,branch);append_text(b,sizeof(b),&p," legacy_id=");append_hex32(b,sizeof(b),&p,legacy);append_text(b,sizeof(b),&p," lion_id=");append_hex32(b,sizeof(b),&p,lion);if(result){append_text(b,sizeof(b),&p," result=");append_text(b,sizeof(b),&p,result);}append_text(b,sizeof(b),&p,"\n");if(p<sizeof(b)){b[p]='\0';write_literal(b);}}
static int snow_exact(size_t w,size_t h,size_t bpc,size_t bpp,size_t bpr,CGBitmapInfo info){return w==SNOW_WIDTH&&h==SNOW_HEIGHT&&bpc==BPC&&bpp==BPP&&bpr==SNOW_BPR&&(uint32_t)info==SNOW_BITMAP_INFO;}
static int lion_exact(size_t w,size_t h,size_t bpc,size_t bpp,size_t bpr,CGBitmapInfo info){return w==LION_WIDTH&&h==LION_HEIGHT&&bpc==BPC&&bpp==BPP&&bpr==LION_BPR&&(uint32_t)info==SNOW_BITMAP_INFO;}
static void log_compat(unsigned int idx,const char *mode,int exact,size_t w,size_t h,size_t bpc,size_t bpp,size_t bpr,CGBitmapInfo info,uint32_t off){char b[512];size_t p=0;log_build_once();append_text(b,sizeof(b),&p,"PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=");append_uint(b,sizeof(b),&p,idx);append_text(b,sizeof(b),&p," mode=");append_text(b,sizeof(b),&p,mode);append_text(b,sizeof(b),&p," exact=");append_text(b,sizeof(b),&p,exact?"YES":"NO");append_text(b,sizeof(b),&p," width=");append_uint(b,sizeof(b),&p,w);append_text(b,sizeof(b),&p," height=");append_uint(b,sizeof(b),&p,h);append_text(b,sizeof(b),&p," bpc=");append_uint(b,sizeof(b),&p,bpc);append_text(b,sizeof(b),&p," bpp=");append_uint(b,sizeof(b),&p,bpp);append_text(b,sizeof(b),&p," bpr=");append_uint(b,sizeof(b),&p,bpr);append_text(b,sizeof(b),&p," bitmapInfo=");append_hex32(b,sizeof(b),&p,(uint32_t)info);append_text(b,sizeof(b),&p," caller_offset=");append_hex32(b,sizeof(b),&p,off);append_text(b,sizeof(b),&p,"\n");if(p<sizeof(b)){b[p]='\0';write_literal(b);}}

static CGDataProviderRef rosetta_CGDataProviderCreateWithData(void *info,const void *data,size_t size,CGDataProviderReleaseDataCallback releaseData){provider_fn fn=provider_original();if(!fn||fn==(provider_fn)&rosetta_CGDataProviderCreateWithData)return NULL;return fn(info,data,size,releaseData);}
static CGImageSourceRef rosetta_CGImageSourceCreateWithDataProvider(CGDataProviderRef provider,CFDictionaryRef options){source_fn fn=source_original();const void *caller=__builtin_return_address(0);uint32_t off=0,id=0,lion=0;int ok=0;CGImageSourceRef r;if(!fn||fn==(source_fn)&rosetta_CGImageSourceCreateWithDataProvider)return NULL;r=fn(provider,options);if(mode_lion()&&r&&caller_info(caller,&off)&&off==COREUI_SHARED_IMAGEIO_SOURCE_RETURN_OFFSET){READ_CALLER_SAVED_U32(COREUI_SHARED_IMAGEIO_SOURCE_SAVED_R30_OFFSET,id,ok);if(ok&&imageio_target(id)&&find_map(id)){lion=find_map(id)->lion_id;bind_source(r,id);log_slot0("SOURCE_BIND","IMAGEIO",id,lion,"BOUND");}}return r;}
static CGImageRef rosetta_CGImageCreate(size_t w,size_t h,size_t bpc,size_t bpp,size_t bpr,CGColorSpaceRef space,CGBitmapInfo info,CGDataProviderRef provider,const CGFloat *decode,bool interp,CGColorRenderingIntent intent){image_fn fn=image_original();const char *mode=NULL;const void *caller=__builtin_return_address(0);uint32_t off=0,id=0,lion=0;int coreui=0,art=0,raw=0,ok=0,exact=0;CGBitmapInfo eff=info;CGImageRef replacement;if(!fn||fn==(image_fn)&rosetta_CGImageCreate)return NULL;if(!mode_valid(&mode))return fn(w,h,bpc,bpp,bpr,space,info,provider,decode,interp,intent);coreui=caller_info(caller,&off);art=coreui&&off==COREUI_ARTFILE_RETURN_OFFSET;raw=coreui&&off==COREUI_SHARED_RAW_IMAGE_RETURN_OFFSET;if(art){unsigned int idx=++gCompatCallIndex;exact=!strcmp(mode,MODE_PASSTHROUGH)?snow_exact(w,h,bpc,bpp,bpr,info):lion_exact(w,h,bpc,bpp,bpr,info);log_compat(idx,mode,exact,w,h,bpc,bpp,bpr,info,off);if(!exact)write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH\n");else if(!strcmp(mode,MODE_PASSTHROUGH))write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH\n");else{eff=(CGBitmapInfo)LION_BITMAP_INFO;write_literal("PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002\n");}}
if(raw){READ_CALLER_SAVED_U32(COREUI_SHARED_RAW_SAVED_R30_OFFSET,id,ok);if(ok&&find_map(id)){lion=find_map(id)->lion_id;if(!strcmp(mode,MODE_PASSTHROUGH)){log_slot0("PASSTHROUGH","RAW",id,lion,"SNOW");}else if(raw_target_geometry(id,w,h,bpr)&&bpc==BPC&&bpp==BPP&&(uint32_t)info==SNOW_BITMAP_INFO&&decode==NULL&&interp&&intent==kCGRenderingIntentDefault){log_slot0("CALL","RAW",id,lion,NULL);replacement=create_slot0(id,space,&lion);if(replacement){log_slot0("RESULT","RAW",id,lion,"ADAPTER_PASS");return replacement;}log_slot0("RESULT","RAW",id,lion,"ADAPTER_FALLBACK");}}}
replacement=fn(w,h,bpc,bpp,bpr,space,eff,provider,decode,interp,intent);if(art&&exact&&!strcmp(mode,MODE_LION))write_literal(replacement?"PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS\n":"PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL\n");return replacement;}
static CGImageRef rosetta_CGImageSourceCreateImageAtIndex(CGImageSourceRef source,size_t index,CFDictionaryRef options){source_image_fn fn=source_image_original();const void *caller=__builtin_return_address(0);uint32_t off=0,id=0,lion=0;CGImageRef original,replacement;CGColorSpaceRef space;if(!fn||fn==(source_image_fn)&rosetta_CGImageSourceCreateImageAtIndex)return NULL;if(!mode_lion()||!caller_info(caller,&off)||off!=COREUI_SHARED_IMAGEIO_FINAL_RETURN_OFFSET)return fn(source,index,options);id=take_source(source);if(!id||!find_map(id))return fn(source,index,options);lion=find_map(id)->lion_id;log_slot0("CALL","IMAGEIO",id,lion,NULL);original=fn(source,index,options);if(!original){log_slot0("RESULT","IMAGEIO",id,lion,"ORIGINAL_NULL");return NULL;}space=CGImageGetColorSpace(original);replacement=create_slot0(id,space,&lion);if(replacement){CGImageRelease(original);log_slot0("RESULT","IMAGEIO",id,lion,"ADAPTER_PASS");return replacement;}log_slot0("RESULT","IMAGEIO",id,lion,"ADAPTER_FALLBACK");return original;}

__attribute__((used)) static struct interpose_tuple sProviderInterpose __attribute__((section("__DATA,__interpose")))={(const void *)(uintptr_t)&rosetta_CGDataProviderCreateWithData,(const void *)(uintptr_t)&CGDataProviderCreateWithData};
__attribute__((used)) static struct interpose_tuple sImageInterpose __attribute__((section("__DATA,__interpose")))={(const void *)(uintptr_t)&rosetta_CGImageCreate,(const void *)(uintptr_t)&CGImageCreate};
__attribute__((used)) static struct interpose_tuple sSourceInterpose __attribute__((section("__DATA,__interpose")))={(const void *)(uintptr_t)&rosetta_CGImageSourceCreateWithDataProvider,(const void *)(uintptr_t)&CGImageSourceCreateWithDataProvider};
__attribute__((used)) static struct interpose_tuple sSourceImageInterpose __attribute__((section("__DATA,__interpose")))={(const void *)(uintptr_t)&rosetta_CGImageSourceCreateImageAtIndex,(const void *)(uintptr_t)&CGImageSourceCreateImageAtIndex};
