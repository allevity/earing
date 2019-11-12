/* 

Mex file to generate sequences of spike trains using either the thinning algorithm (option 1, default) or the binning algorithm (option 2), 
using a stochastic refractory period described below. Before using from Matlab run `mex MAP_AN_generatePoissonSpikeTrains.c` within folder.

Usage:

spkTrains = MAP_AN_generatePoissonSpikeTrains(nbFiber, nbBinsRefrac, arrayRate)
spkTrains = MAP_AN_generatePoissonSpikeTrains(nbFiber, nbBinsRefrac, arrayRate, algo)
spkTrains = MAP_AN_generatePoissonSpikeTrains(nbFiber, nbBinsRefrac, arrayRate, algo, printOption)

where 

Inputs:
- nbFiber is a (double) integer giving the number of auditory fibers each channel should innervate 
    (so the number of spike trains simulated using the same law, defined as a row of arrayRate)
- nbBinsRefrac is a (double) integer giving the absolute refractory period in number of bins. 
    For example, for a sampling rate of 100kHz (so that each column of arrayRate represents 1e-5s), 
    nbBinsRefrac = 75 represents an absolute refractory perdio of 0.75ms. 
    The way refractoriness is simulated is described in note 1 below.
- arrayRate is a (real double) array such that each row represents the Poisson firing rate (in number of spikes per bin). See note 2 below.

Optional inputs:
- algo is a (double) integer, that should be 1 or 2. Algorithm '1' is the thinning method, algorithm 2 is the binning method. Default value is 1 (thinning).
- printOption is a double (boolean) to print out a lot of information, used for debugging purposes. Default value is 0 (no printing).

Output:
- spkTrains is a boolean array of size (nbFiber * size(arrayRate,1)) x size(arrayRate, 2), such that the first nbFiber rows are generated using the first row of arrayRate as 
    firing rate and subsequent groups of nbFiber rows are generated using the same row of arrayRate.

Note 1: Refractoriness generation
    Refractoriness is implemented as a uniform distribution between R_A and 2*R_A. 
    After a spike, this value is generated and all spikes within this refractory period are removed.
    The value 0 is a valid refractory period (no refractoriness).

Note 2: Thinning and Binning
    For small values of firing rate and without refractoriness, algorithms 1 and 2 produce similar statistics. They diverge as the rate is close to 1. 
    This effect disappears when refractoriness is added.

Examples (stochastic results):
y1 = MAP_AN_generatePoissonSpikeTrains(1,0, [1 1 1 1 1], 2);
y2 = MAP_AN_generatePoissonSpikeTrains(1,0, [1 1 1 1 1], 1);
y3 = MAP_AN_generatePoissonSpikeTrains(3,0, [1 0 0 0 1], 2);
y4 = MAP_AN_generatePoissonSpikeTrains(3,10,[1 1 1 1 1;0 0 1 0 0], 2);

y1 = 
  1 1 1 1 1

y2 = 
  1 1 1 0 1

y2 = 
  1 0 0 0 0
  1 0 0 0 0
  1 0 0 0 0
  0 0 1 0 0
  0 0 1 0 0
  0 0 1 0 0


% PSTH generation
% Parameters
t = 0:0.01:1;
R_A = 75;
n = 1000;
ar = sin(t).^2;

% Method 1:
PSTH1 = zeros(size(t));
for kk=1:n
  PSTH1 = PSTH1 + MAP_AN_generatePoissonSpikeTrains(1,R_A,ar);
end
PSTH1 = PSTH1 / n;

% Method 2
PSTH2 = mean(MAP_AN_generatePoissonSpikeTrains(n,R_A,ar),1);



Written by Alban, February 9th 2017

 */

#include "mex.h"
#include "matrix.h"
#include <stdlib.h>
#include <time.h>     /* To reinitialise randomness */
#include <math.h>     /* For pow() power function */

 /* Redefine function intpow for doubles (a to the power floor(b)), 
  because unsure how to call function for mex.
  Replace by call to initial intpow when knows how-to */
  double intpow( double a, double b){
    return pow(a, floor(b));
  }

/* Generate a uniform random variable between 0+ and 1. RAND_MAX=2147483647 on development machine */
  double getRand (){ 
    return (double) (rand()+1.0)/(double)(RAND_MAX+1.0);
  }

/* Simulate an expo(lambda) random variable */
  double getExp(double lambda) {
    return -log(getRand())/lambda;
  }

/* Calculate a random refractory period */
  int getRefractoryPeriod (int AbsRefInt){
    return (int) AbsRefInt + floor(getRand() * AbsRefInt);
  }

/* Logical check that current proba bigger than rand() (Poisson generation) */
  mxLogical isBiggerThanRand(double prob){
    return prob > getRand();
  }

  void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]){
    
  /* Output */
  #define ANspikes_out plhs[0]

  /* Inputs */
  #define nFibersPerChannel_in prhs[0]
  #define lengthAbsRefractory_in prhs[1]
  #define ANproboutput_in prhs[2]
  #define algo_in prhs[3]
  #define log_in prhs[4]
  /*#define psth_in prhs[4]*/

  /* Initialise randomness used (or fix it by replacing with srand(123) for example) */
    srand ( time(NULL) );  

  /* Variables */
    /* Defines algorithm to use to generate spike trains. Default is 1 (thinning method) */
    int algo = 1;
  /* Defines number of spike trains to average on a single row */
    int psth = 1; 
  /* Boolean to define whther we save a given log file */
    int savelog = 0;     /* boolean: is a log required? */
    int printStuff = 0;  /* boolean: should we print stuff out? (yes if log required; slows downs calculations a LOT) */
    char *input_buf;     /* log file, 5th argument */
    FILE *f;
  /* Indices in loops */
    int ind, ind_release, fibNum, indList = 0, kk, nPointsRef,row, row_release, col;     
    int nFibPerChan, AbsRefInt;
    double *ANproboutput, *lengthAbsRef, *nFibPerChan_doub;
 
  /* Maximal rate per row, exponential variable */
    double lambdaMax, expo; 

  /* Read inputs */
  /* length of refractory period */
    lengthAbsRef      = (double *)mxGetPr(lengthAbsRefractory_in); 
    AbsRefInt         = (int) *lengthAbsRef;
  /* Used to be for fiber generation */
    nFibPerChan_doub  = (double *)mxGetPr(nFibersPerChannel_in);  
    nFibPerChan       = (int) *nFibPerChan_doub; 
  /* Read the matrix of firing rate */
    ANproboutput      = (double *)mxGetPr(ANproboutput_in); 

   /* Prepare output */
    int ANspik_sizeM, ANspik_sizeN; 
    ANspik_sizeM = mxGetM(ANproboutput_in);
    ANspik_sizeN = mxGetN(ANproboutput_in);

    int dims[2];
    dims[0] = nFibPerChan * ANspik_sizeM;
    dims[1] = ANspik_sizeN;

    /* Optional arguments */
    if (nrhs >= 4){  algo = (int)mxGetScalar(algo_in); }
    if (nrhs >= 5){  
    size_t buflen;

    /* input must be a string */
    if ( mxIsChar(log_in) == 1){

      /* input must be a row vector; if empty, no log required */
      if (mxGetM(log_in)==1){ 
        /*mexErrMsgIdAndTxt( "MATLAB:MAP_AN_generatePoisson:inputNotVector", "Input must be a row vector.");*/
    
        mexErrMsgIdAndTxt("MATLAB:MAP_AN_generatePoisson:optionAbandonned", "Using this log option would make Matlab crash. Use diary(logfile) instead.");

        /* Get the length of the input string */
        buflen = (mxGetM(log_in) * mxGetN(log_in)) + 1;

        /* Copy the string data from log_in into a C string input_ buf.    */
        input_buf = mxArrayToString(log_in);

        savelog = 1;
        f = fopen(input_buf, "w+"); 
        if (f == NULL) { mexErrMsgIdAndTxt( "MATLAB:MAP_AN_generatePoisson:fileNotOpen", "File %s could not be created.", input_buf); }
        }
      } else if ( mxIsDouble(log_in)==1 || mxIsLogical(log_in)==1 ){
        printStuff = (int)mxGetScalar(log_in); 
      }
      else {
        mexErrMsgIdAndTxt( "MATLAB:MAP_AN_generatePoisson:inputNotStringNorDouble", "Input must be a string (logfile) or a double (0 or 1 to print stuff out).");}
      }

  /* Verifications */
    if (mxGetM(nFibersPerChannel_in)   > 1 || mxGetN(nFibersPerChannel_in)   > 1) {mexErrMsgTxt("First argument should be a doulbe");}
    if (mxGetM(lengthAbsRefractory_in) > 1 || mxGetN(lengthAbsRefractory_in) > 1) {mexErrMsgTxt("Second argument should be an integer (given as double)");}
    if (mxGetM(ANproboutput_in) > mxGetN(ANproboutput_in))                        {mexErrMsgTxt("Third argument should be a double array, each row being a firing rate");}
    if (nrhs<3){                mexErrMsgTxt("Not enough input arguments: (int) nbFibers, (int)nbBinsAbsoluteRefractoriness, (double array)rate of firing, (opt int) algorithmID)");}
    if (ANspik_sizeM == 0){     mexErrMsgTxt("SizeM of ANproboutput_in not as expected\n"); }
    if (ANspik_sizeN == 0){     mexErrMsgTxt("SizeN of ANproboutput_in not as expected\n"); }
    if (nFibPerChan  <  1){     mexErrMsgTxt("nFibPerChan is not as expected\n"); }
    if (printStuff > 1){        mexErrMsgIdAndTxt( "MATLAB:MAP_AN_generatePoisson:valueNotBoolean", "The double value given as fifth element (%d) is bigger than 1. Should be 0 or 1", printStuff); }

    /*
    if (nrhs >= 5){  psth = (int)mxGetScalar(psth_in); }
    if (psth < 1){              mexErrMsgTxt("PSTH is negative. Should be positive integer\n"); }
    */


  /* Allocate memory: logical if psth=1, double otherwise */
    if (psth != 1){    mexErrMsgTxt("Option cancelled for now: PSTH should be calculated as a loop within .m file (a=a+MAP(AN_generate))");
      double *ANspikes; 
      ANspikes_out = mxCreateDoubleMatrix((mwSize) dims[0], (mwSize) dims[1], mxREAL);
      ANspikes = (double *)mxGetPr(ANspikes_out);
    }

  /* Booleans of minimal size with mxLogical */
    mxLogical *ANspikes; 
    ANspikes_out = mxCreateLogicalMatrix((mwSize) dims[0], (mwSize) dims[1]);
    ANspikes = (mxLogical *)mxGetLogicals(ANspikes_out);
 

    /*printf("(float)log(0)=%f, (int)log(0)=%d, floor(log(0))=%d, isfinite(log(0))=%d\n", (float)log(0),(int)log(0), (int)floor(log(0)), isfinite(log(0)));*/
    /*         (float)log(0)=-inf, (int)log(0)=-2147483648, isfinite(log(0))=0 */

    /* Shows some very interesting patterns...*/
    /*
    for (ind = 0; ind < 1000; ind++){
      printf("%f: (10**(-%d))  (float)log(pow(10,(-ind)))=%f,  %d\n", (float)pow(10,(-ind)), ind, (float)log(pow(exp(1),(-ind))), pow(10,(-ind))==0);
    }
    */

    /* Use the various printfs in debug mode */
    if (savelog==1){ printStuff = 1; };

    switch (algo) {

    /* Thinning algorithm for spike generation */
      case 1:

      for (row_release = 0; row_release < ANspik_sizeM; row_release++){

        /* Get max rate of this row */
        lambdaMax = 0.0;
        for (col = 0; col < dims[1] ; col++) {
          ind_release = row_release + col * ANspik_sizeM;
          lambdaMax = (ANproboutput[ind_release] > lambdaMax ? ANproboutput[ind_release] : lambdaMax);
        }

        /* The rate should be positive or null */
        lambdaMax = (lambdaMax > 0 ? lambdaMax : 0.0);
        if (printStuff==1){ printf("row_release=%d,       lambdaMax=%f\n", row_release, (float) lambdaMax); } /* fprintf(f, */

        /* Generate spike trains for each row by simulating exponential variable */
        for (row = nFibPerChan * row_release; row<nFibPerChan*(row_release+1); row++){
          expo = getExp(lambdaMax);
          col = (int) expo;
          indList = 0;

          if (isfinite(expo) && (int)expo < dims[1] && expo >= 0){
            do  {
              ind = row + col * dims[0];
              ind_release = row_release + col * ANspik_sizeM;
              /* Add spike if current proba bigger than rand (thinning algorithm), and if no spikes already (to account for expos < 1) */
              if (!ANspikes[ind]){
                ANspikes[ind] = isBiggerThanRand(ANproboutput[ind_release]/lambdaMax) ;
                 if (printStuff==1){printf("r_r=%d r=%d As=%d e=%f\n", row_release, row, (int) ANspikes[ind], (float)expo); }
              }
              /* To account for multiple spikes within a bin, it is enough to replace 
              ANspikes[ind] = by ANspikes[ind] += and to change ANspikes into a double (or integer) array */
                            
              expo += getExp(lambdaMax);
              col = (int) expo;
              /* Even though expo should always be finite, some weird behaviours may appear, with expo infinite and col negative. */
            } while ( col < dims[1] && isfinite(expo) ); 
          }

        }
      }

      break;

    /* Binwise generate spike trains as Poisson Process, without refractoriness yet */
    /* The row for ANproboutput should be constant for nFibPerChan values of "row" */
    /* row_release = (int) floor((double) row / (double) nFibPerChan); */
    /* This is the index, row-major, for ANproboutput */
    case 2:

    for (fibNum = 0; fibNum < nFibPerChan ; fibNum++){
     ind = fibNum;
     ind_release = 0;

     for (col = 0; col < ANspik_sizeN ; col++) {
      for (row = 0; row < ANspik_sizeM; row++){
        ANspikes[ind] = isBiggerThanRand(ANproboutput[ind_release]);
        ind += nFibPerChan;
        ind_release += 1;
      }
    }
  }
  break;

  default:

  mexErrMsgTxt("Fourth argument of MAP_AN_generatePoisson should be 1 (thinning method) or 2 (binwise simulation)\n");


}

  /* Deallocate mxArray, even though Matlab is supposed to do it; may cause a crash */
  /*mxDestroyArray((mxArray *)ANspikes); */

if (AbsRefInt  <  1){  
  /* No refractoriness required */
 return; 
}

/* Refractory period; having two loops might be too slow. Could send output of find()? */
ind = -1;
for (col = 0; col < dims[1] ; col++) {
  for (row = 0; row < dims[0]; row++){

    /* Running index */
    ind += 1;

    /* If there's a spike, apply refractory period */
    if (ANspikes[ind]) {

      /* Random refractory period*/
      nPointsRef = getRefractoryPeriod(AbsRefInt);

      /* Comment on refractoriness: to have the AbsRefInt as the first spike authorised, 
      replace col+nPointsRef+1* by col+nPointsRef and
      replace kk<=nPointsRef by kk<nPointsRef */

      /* Reduce if end of times */
      nPointsRef = ((col+nPointsRef < ANspik_sizeN) ? nPointsRef : ANspik_sizeN - col -1);
      if (printStuff==1){ printf("c=%d r=%d i=%d nP=%d [0]=%d\n", col, row, ind, nPointsRef, ind+nPointsRef * dims[0] ); }

      /* Remove spikes every [ANspik_sizeM] indices, [nPointsRef] times */
      for (kk=1; kk <= nPointsRef ; kk++){
        ANspikes[ ind + kk * dims[0] ] = (mxLogical) 0;
      } 

    }


  }
  if (savelog==1){
    mxFree(input_buf);
    fclose(f);
  }
}

return;
}