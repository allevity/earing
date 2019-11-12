

#include "mex.h"
#include "matrix.h"

void mexFunction(int nlhs, mxArray *plhs[],int nrhs, const mxArray *prhs[])
{
	/* Outputs */
	#define probref_out plhs[0]

	/* Inputs */
	#define prob_in prhs[0]
	#define Wfull_in prhs[1]
	#define dt_in prhs[2]
	#define horiz_in prhs[3]


	double *probref, *prob, *Wfull;
	int ind, col, row, col_b, cHoriz;   
	double su, dt, horiz; /* sum  and differential time */  


    prob  = (double *)mxGetPr(prob_in); 
    Wfull = (double *)mxGetPr(Wfull_in); 
	dt    = (double)mxGetScalar(dt_in); 
	horiz = (double)mxGetScalar(horiz_in); 

	int dims[2];
    dims[0] = mxGetM(prob_in);
    dims[1] = mxGetN(prob_in);

    probref_out = mxCreateDoubleMatrix((mwSize) dims[0], (mwSize) dims[1], mxREAL);
    probref = (double *)mxGetPr(probref_out);


    /* Declare first column */ 
    for (ind=0; ind < dims[0] ; ind ++){
    	probref[ind] = prob[ind];
    }
    for (col=1; col < dims[1] ; col ++){


    	/* Calculate with probref's columns between 0 and col-1 or col-horiz and col-1 */
    	cHoriz = (col * dt < horiz ? col : (int)(horiz/dt));

    	for (row = 0; row < dims[0] ; row++) {
    		ind = row+col*dims[0];
    		su = 0.0;
    		for (col_b = 0; col_b < cHoriz; col_b++){
	    		/*printf("col_b=%d, col-1-col_b=%d\n", col_b, col-1-col_b);*/
    			su += Wfull[col_b] * probref[row+(col-1-col_b)*dims[0]]; /*Check second index, might be + or - 1 */
    		}
    		probref[ind] = prob[ind] * (1 - su);
    	}
    	

    }
}