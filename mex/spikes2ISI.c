/* Mex file computing the ISI matrix: column-wise, a (full and double) spike train is transformed
 * into a vector of the same size, where every value is the current Interspike-Interval
 * (number of 0s between the previous and next spike).  
 *
 * Example in Matlab, after running 'mex path/to/spikes2ISI.c'
 
A = [0 0 1;0 0 0; 1 0 1; 0 1 0]';
data = zeros(size(A));
spikes2ISI(A,data);

A =

     0     0     1     0
     0     0     0     1
     1     0     1     0

data =

     2     3     2     1
     2     3     2     2
     1     3     1     2
  
*/

#include "mex.h"
#include "matrix.h"

void mexFunction(int nlhs, mxArray *plhs[],int nrhs, const mxArray *prhs[])
{
  /* Inputs */
  #define matrix_spk_in prhs[0]
  #define matrix_ISI_in prhs[1]

  /* Variables */
  double ISI;          /* ISI value. Could be integer, but float for consistency of matrices */
  int ind = 0;        /* Running index */
  int indExplo = 0;   /* Index that will go from 'row' to the index of next spike */ 
  int prevCol;        /* To avoid calculating product (mat_size1 * idx) many times*/
  int rowBase;        /* Current row position before searching for next spike */
  int idx;            /* Column index */
  int row;            /* Row index */
  int mat_size1, mat_size2;   /* Size of matrices (assumed same for matrices) */
  int mat_size1c, mat_size2c; /* Size of matrices (check it's the same) */
  double *matrix_ISI, *matrix_spk; /* Copy inputs */

  /* Copy original input vectors, get size of C and matrix */
  matrix_ISI = (double *) mxGetPr(matrix_ISI_in);  
  matrix_spk = (double *) mxGetPr(matrix_spk_in);
  mat_size1  = (int) mxGetM(matrix_spk_in);
  mat_size2  = (int) mxGetN(matrix_spk_in);
  mat_size1c = (int) mxGetM(matrix_ISI_in);
  mat_size2c = (int) mxGetN(matrix_ISI_in);

  if (mat_size1c != mat_size1 || mat_size2c != mat_size2){
    printf("The two matrices given as input should have the same size!'\n");
  }

    /* printf("Per column\n 0 mat_size2 60 61"); */
    for (idx = 0; idx < mat_size2 ; idx++) {
      row = 0;
      rowBase = 0;
      prevCol = mat_size1 * idx;
      while ( rowBase < mat_size1 ){

        /* The next 'while' loop is an exploration to obtain the ISI: until spike found*/
        indExplo = rowBase;

        /* When a spike is found along a column, stop search */
        do { 
          indExplo++;
        }
        while ( indExplo < mat_size1 && matrix_spk[prevCol+indExplo] < 0.5 );
          
          
        ISI = (double) (indExplo - rowBase);

        /* Fill rows up to index indExplo with ISI */
        for (row = rowBase; row < indExplo; row++){
          matrix_ISI[row + prevCol] = ISI; 
        }
        rowBase = indExplo;

        
      }
    } 
 
  return;
}
