/* Mex file subsampling spike trains.
 *
 * Example in Matlab, after running 'mex path/to/thisFile.c' 
 * Applied this: http://fr.mathworks.com/matlabcentral/answers/246507-
 * why-can-t-mex-find-a-supported-compiler-in-matlab-r2015b-after-i-upgraded-to-xcode-7-0
 * to get mex to work
 
A = [0 0 1 1 1 1 1 1 0 0 1; 0 0 1 0 1 0 0 1 0 0 1; 0 0 0 0 0 0 0 0 0 0 0]'

A =

     0     0     0
     0     0     0
     1     1     0
     1     0     0
     1     1     0
     1     0     0
     1     0     0
     1     1     0
     0     0     0
     0     0     0
     1     1     0

n = 3;
subsampleSpikeTrains(A,n);
disp(A);

A =

     0     0     0
     0     0     0
     1     1     0
     0     0     0
     0     0     0
     1     0     0
     0     0     0
     0     0     0
     0     0     0
     0     0     0
     1     1     0
  
*/

#include "mex.h"
#include "matrix.h"

void mexFunction(int nlhs, mxArray *plhs[],int nrhs, const mxArray *prhs[])
{
  /* Inputs */
  #define matrix_spk_in prhs[0]
  #define n_in prhs[1]

  /* Variables */
  int ind = 0;        /* Running index */
  int indExplo = 0;   /* Index that will go from 'row' to the index of next spike */ 
  int col;            /* Column index */
  int row;            /* Row index */
  int mat_size1, mat_size2;   /* Size of matrices (assumed same for matrices) */
  int n_size1c, n_size2c;     /* Size of matrices (check it's the same) */
  double  *n_double, *matrix_spk;        /* Copy inputs */
  int n;

  /* Copy original input vectors, get size of n and matrix */
  n_double = (double *) mxGetPr(n_in);  
  n = (int) *n_double;
  matrix_spk = (double *) mxGetPr(matrix_spk_in);
  mat_size1  = (int) mxGetM(matrix_spk_in);
  mat_size2  = (int) mxGetN(matrix_spk_in);
  n_size1c = (int) mxGetM(n_in);
  n_size2c = (int) mxGetN(n_in);

  if (n_size1c != 1 || n_size2c != 1){
    printf("The second input of subsampleSpikeTrains should be an integer!'\n");
  }


  for (col = 0; col < mat_size2 ; col++) {

    indExplo = 0;

    for (row = 0; row < mat_size1 ; row++) {

      /* Index in the matrix */
      ind++;

      /* Counting number of spikes in a column */
      if ( matrix_spk[ind] == 1 ){

        /* Keeps one spike every $n$, while incrementing indExplo. Always keeps the first spike. */
        if ( indExplo++ % n != 0 ){
          /* printf("ind=%d,indExplo=%d,n=%d\n",ind,indExplo,n); */

          matrix_spk[ind] = 0;
        }
      }

        
      }
    } 
 
  return;
}
