#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "WarmthCurve.h"
typedef struct{double m[9];}Matrix;
#define CHECK(x) do{if(!(x)){fprintf(stderr,"FAIL line %d\n",__LINE__);return 1;}}while(0)
int main(){@autoreleasepool{
 void*h=dlopen("/System/Library/Frameworks/MediaAccessibility.framework/MediaAccessibility",2);
 CFTypeRef(*gray)(double)=dlsym(h,"MADisplayFilterCreateGrayscale");Matrix(*get)(CFTypeRef)=dlsym(h,"MADisplayFilterGetMatrix");
 if(!gray||!get)return 2;CFTypeRef f=gray(1);Matrix m=get(f);CFRelease(f);
 for(int c=0;c<3;c++)CHECK(fabs(m.m[c]-m.m[3+c])<1e-6&&fabs(m.m[c]-m.m[6+c])<1e-6);
 double g[3];WarmthGains(0,g);CHECK(g[0]==1&&g[1]==1&&g[2]==1);
 WarmthGains(1,g);CHECK(fabs(g[1]-.55)<1e-6&&fabs(g[2]-.12)<1e-6);
 WarmthGains(2,g);CHECK(fabs(g[1]-.20)<1e-6&&fabs(g[2]-.005)<1e-6);
 double previousG=1,previousB=1,previousRatio=1;
 for(int step=0;step<=300;step++){
 double strength=step/100.0;WarmthGains(strength,g);
 CHECK(g[0]==1&&g[1]>=0&&g[2]>=0&&g[1]<=previousG&&g[2]<=previousB&&(g[1]==0||g[2]/g[1]<=previousRatio+1e-12));
 previousG=g[1];previousB=g[2];previousRatio=g[1]>0?g[2]/g[1]:0;
 // Primary and neutral input colors must all produce the same output chromaticity.
 for(int input=0;input<3;input++)CHECK(fabs((m.m[3+input]*g[1])/(m.m[input]*g[0])-g[1])<1e-6);
 }
 WarmthGains(3,g);CHECK(g[0]==1&&g[1]==0&&g[2]==0);
 WarmthMatrix3 color=MakeWarmthMatrix(0,0),grayZero=MakeWarmthMatrix(0,1),colorRed=MakeWarmthMatrix(3,0),grayRed=MakeWarmthMatrix(3,1);
 for(int r=0;r<3;r++)for(int col=0;col<3;col++){CHECK(color.m[r*3+col]==(r==col?1:0));CHECK(fabs(grayZero.m[r*3+col]-m.m[r*3+col])<1e-6);CHECK(colorRed.m[r*3+col]==grayRed.m[r*3+col]);if(r>0)CHECK(colorRed.m[r*3+col]==0);}

 puts("PASS: native grayscale rank-one matrix, preserved old endpoint, orange and red endpoints, 301-step monotonic chromaticity and fixed red gain.");return 0;
}}
