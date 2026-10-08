#pragma once
#include <math.h>
// Keep the original 0..1 range unchanged; add stronger orange (1..2) and red monochrome (2..3).
static inline void WarmthGains(double strength, double gains[3]) {
 strength=fmax(0,fmin(3,strength));gains[0]=1;
 if(strength<=1){gains[1]=1-.45*strength;gains[2]=1-.88*strength;}
 else if(strength<=2) {gains[1]=.55*pow(.20/.55,strength-1);gains[2]=.12*pow(.005/.12,strength-1);}
 else {double remaining=3-strength;gains[1]=.20*pow(remaining,-log(.20/.55));gains[2]=.005*pow(remaining,-log(.005/.12));}
}

typedef struct {double m[9];} WarmthMatrix3;
static inline WarmthMatrix3 MakeWarmthMatrix(double strength,int grayscale){
 strength=fmax(0,fmin(3,strength));double gains[3];WarmthGains(strength,gains);double luma[3]={.30,.59,.11};double mix=grayscale?1:strength/3;WarmthMatrix3 result;
 for(int row=0;row<3;row++)for(int col=0;col<3;col++)result.m[row*3+col]=((1-mix)*(row==col?1:0)+mix*luma[col])*gains[row];return result;
}
