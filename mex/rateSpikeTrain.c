/*
Mex file to calculate the rate of a raster plot, using a predefined window 
and the indices at which to start the calculation.
The spike trains/rate are vertical.

Compile by calling (in mex/ folder)
	mex rateSpikeTrain.c

Example: 

% Vertical spike train
spkTr = floor([1.5*rand(1000,1), 5*rand(1000,1), 10*rand(1000,1)]);

% indices to start windowing
beginInd = 1:20:(1000-20);

% Window (horizontal or vertical)
hammingWindow = hann(40);

% Run
R = rateSpikeTrain(spkTr, beginInd, hammingWindow)

%% 
%BUG REPORT: 
R = (1:49)';
rateSpikeTrain(R, spkTr, beginInd, hammingWindow)
R = (1:49)' 
% no longer reintinitalises R. This is probably due to Matlab internals that avoid recalculating.
% changing the variable name or using 1:48 does reinitialise it though.

*/ 

#include "mex.h"
#include "matrix.h"

void mexFunction(int nlhs, mxArray *plhs[],int nrhs, const mxArray *prhs[])
{
	/* Outputs */
	#define R_out plhs[0]

	/* Inputs */
	#define spikeTrain_in prhs[0]
	#define beginInd_in prhs[1]
	#define hammingWindow_in prhs[2]

	 /* Variables */
	int ind = 0;        /* Running index */
	int indHann = 0; 	/* Running index in Hann window */
	int cind; 			/*  */
	int col;            /* Column index */
	int row;            /* Row index */
	double val;         /* Value to calculate */
 	double *R, *spikeTrain, *hammingWindow; /* Copy inputs */
 	double *beginInd;
 	int R_size1, R_size2, spkTr_s1, len_hann, len_beginInd; /* Size of R, Hann, begin_ind */

	/* Copy original input vectors, get size of C and matrix */
	beginInd   		= (double *) mxGetPr(beginInd_in);
	spikeTrain    	= (double *) mxGetPr(spikeTrain_in);
	hammingWindow 	= (double *) mxGetPr(hammingWindow_in);  

	/* Get sizes */
	/* Begin_ind and hann: Horizontal or vertical  */
	/* len_beginInd Should be equal to R_size1 */
	len_beginInd = (int) (mxGetM(beginInd_in)<mxGetN(beginInd_in) ? mxGetN(beginInd_in) : mxGetM(beginInd_in));
	len_hann     = (int) (mxGetM(hammingWindow_in)<mxGetN(hammingWindow_in) ? mxGetN(hammingWindow_in) : mxGetM(hammingWindow_in));
  
  	if (mxGetM(beginInd_in) == 0      || mxGetN(beginInd_in) == 0){          mexErrMsgTxt("Size of len_beginInd is 0\n"); }
  	if (mxGetM(hammingWindow_in) == 0 || mxGetN(hammingWindow_in) == 0){     mexErrMsgTxt("Size of len_hann is 0\n"); }

	 /*	Allocate memory for R */
    int dims[2];   /*mxGetM(beginInd_in); */
    dims[0]   = (int) len_beginInd;
    dims[1]   = (int) mxGetN(spikeTrain_in);
	spkTr_s1  = (int) mxGetM(spikeTrain_in);
    R_out = mxCreateDoubleMatrix((mwSize) dims[0], (mwSize) dims[1], mxREAL);
    R = (double *)mxGetPr(R_out);

	/*R_size1 = (int) mxGetM(R_out);
	R_size2 = (int) mxGetN(R_out);*/
	/*printf("%d, %d, %d\n", dims[0], dims[1], (dims[1]-1) * spkTr_s1 + beginInd[dims[0]-1]);*/
    if (spkTr_s1*(dims[1]-1)+beginInd[len_beginInd-1]+hammingWindow[len_hann-1]>spkTr_s1*dims[1]){ mexErrMsgTxt("beginInd seems to be too long; consider removing last indices\n"); }
	

	/* Run the loop */
	for (col = 0; col < dims[1] ; col++) {
      for (row = 0; row < dims[0]; row++) { /* R or beginInd, because same size */

      	/* Initial index in spikeTrain, column-major */
        cind = (int) col * spkTr_s1 + beginInd[row];
        /* printf("%d, %d, %d, %f, %d\n", cind, ind, (int) beginInd[row], R[ind], (int) R[ind]); */
        val = 0;
        for (indHann = 0; indHann < len_hann; indHann++) {
        	val += spikeTrain[cind + indHann] * hammingWindow[indHann];
        }
        R[ind++]   = val;
      }
    } 
 }