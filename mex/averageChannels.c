/*
Averages columns of feats_in into nbFeat_in features.
Last feature contains remaining features.

Usage:
	f = averageChannels(randn(128, 3), 31);
	size(f) =
		[31, 3]

Written by Alban, January 2017
*/ 

#include "mex.h"
#include "matrix.h"
#include <math.h>     /* For pow() power function */

void mexFunction(int nlhs, mxArray *plhs[],int nrhs, const mxArray *prhs[])
{
	/* Outputs */
	#define meanfeat_out plhs[0]

	/* Inputs */
	#define feats_in prhs[0]
	#define nbFeat_in prhs[1]

	 /* Variables */
	int ind, indFeats, kk;        		/* Running indices */
	int initNbFeat = 0, final_n; 		/* Numner of fibers */
	int col, n, nn, maxInd, nbFeat;  	/*  */
	double val;         /* Value to calculate */
 	double *feats, *nbFeat_do, *meanfeat;  /* Copy inputs */


	/* Copy original input vectors, get size of C and matrix */
	feats 		= (double *) mxGetPr(feats_in);
	nbFeat_do  	= (double *) mxGetPr(nbFeat_in);
	nbFeat 		= (int) *nbFeat_do;
	initNbFeat  = (int) mxGetM(feats_in);
	
	/* n: Number of channels averaged per feature (only the last one may be bigger) */
	n = floor((float)initNbFeat/(float)nbFeat); 
	/* some fibers might be missing */
	final_n = n + initNbFeat - nbFeat * n;
	if (initNbFeat <= nbFeat){  mexErrMsgTxt("There are less channels than required features\n"); }


	 /* Output */
	int dims[2];  
    dims[0]   = (int) nbFeat;
    dims[1]   = (int) mxGetN(feats_in);
    meanfeat_out = mxCreateDoubleMatrix((mwSize) dims[0], (mwSize) dims[1], mxREAL);
    meanfeat = (double *)mxGetPr(meanfeat_out);

	ind = 0;
	indFeats = 0;
	for (col = 0; col < dims[1] ; col++) {
		for (nn = 1; nn <= dims[0]; nn++) {
			val = 0;
			maxInd = ( nn < nbFeat ? n : final_n );
      		for (kk = 0; kk < maxInd; kk++) { 
				val += feats[indFeats++];
      		}
      		meanfeat[ind++] = val/(double)maxInd;
    	}
    } 
	return;

	
 }