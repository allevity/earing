# Earing
Repository for [ear](https://en.wikipedia.org/wiki/Ear) models
and associated numerical experiments for research purposes.

Fully Object-Oriented Programming-oriented,
most important objects (such as an ear, ear components,
experiment or speech recognition run) are based on `RunObject.m`.
They inherit from this abstract class,
meaning that their main function is to be `run`. Their `name`
property is used to concatenate in a single string all their parameters.
For example, the name of an ear contains the names of its outer middle,
of its auditory nerve, ...

- - - -

# Cochlear Models

## Sumner2003

* Implementation of 'A nonlinear filter-bank model of the guinea-pig cochlear nerve: Rate responses'
(Christian Sumner and Towel P. O'Mard, 2003).
* The sound arrives to the ___Outer Middle Ear___, which moves the stapes.
Their velocity affects the liquid in the cochlear, thus,
in the ___Basilar Membrane___, the little hair on Inner Hair Cells,
the ___Ihc Cilia___, will move back-and-fro, allowing the soma to react
and to send ions to their synapses: the ___An-Ihc Synapses___ will then
send neurotransmitters to the ___Auditory Nerve___.
* All these elements are individually modeled, and their model's files are
those highlightened words
(found in `matlab/models/ear/components/(OuterMiddleEar|BasilarMembrane|...).m`).
* File `matlab/models/ear/EarSumner2002.m` shows how each output is passed on
to the next processing stage.
* Note that the spiking behaviour is different from the original paper,
because the spike generation mechanism was replaced by a real inhomogeneous
Poisson Process. The new method, a proper Poisson process, reduces the spiking activity.


- - - -


# Getting Started


## Requirements

* Signal Processing toolbox for upsampling waveforms.

## Download

Download the repo
```
git clone git@bitbucket.org:allevity/earing.git
cd earing/
```


## Mex files

To speed-up the big calculations, MEX-files are used to compute matrices.
They may be available for your system in `mex/`, otherwise you need to compile them:

```
cd mex/
mex MAP_AN_forLoop_mex.c MAP_applyRefractoriness_mex.c averageChannels.c \
    spikes2ISI.c MAP_AN_generatePoissonSpikeTrains.c MAP_finalForLoop_mex.c \
    rateSpikeTrain.c subsampleSpikeTrains.c
cd ../
```

- - - -

#  Run the model

The method `EarSumner2002.run` receives either the path to an mp3 file
or the array read from it. You may change the sound level of the ear before
running.

```
ear = EarSumner2002();
ear.db = 79.5;  % to change sound level (default value 80dB)

% Your mp3 file should be small: the temporal scale necessary to run this
% biomechanical model is so fine that matrices easily become huge.
ear.run('/path/to/sound_file.mp3'); % runs the OME, the BM, ...

figure;
ear.an.plot();  % imagesc of the firing probability at each time frame and fiber
```

The object `ear` then contains all important variables calculated during
the run. Executing `ear.clean()` removes these variables to reduce the
object's size.

If `ear.synapse.n_fibers_per_type_per_channel>0` (defaults to `1`),
spikes are also generated and saved in `ear.an.spikes_sparse` as a sparse
matrix of 0's and 1's.
`ear.synapse.n_fibers_per_type_per_channel` fibers of each type are generated
for each `ear.bm.best_frequency`.


To change the parameters, a structure needs to be provided at ear's initialisation.
A useful example that changes a good section of the parameters:
```
gmax_ca = 7.2e-9;  % gmax_ca and ca_thresh together define the fiber type
ca_thresh = 4.48e-11;
best_frequencies = [250, 500, 1000, 3000, 6000, 12000, 24000];
externalResonanceFilters = [ 0 1 4000 25000; 0 1 4000 25000; 0 1  700 30000;   0 1  700 30000;    0 1  700 30000];
params = ...
 struct(...
    'model', @EarSumner2002, ...
    'db', db, ...  
    'ome', struct(...
        'externalResonanceFilters', externalResonanceFilters), ...
    'bm',  struct(...
        'drnl', struct(...
            'lin', struct(), ...
            'gt', struct(...
                'nl', struct(...
                    'lin', struct())),...
            'lp', struct(...
                'nl', struct(...
                    'lin', struct()))), ...
        'best_frequencies', best_frequencies), ...
    'cilia',  struct(),...
    'synapse',  struct(...
        'n_fibers_per_type_per_channel', 1, ...
        'presynapse', struct(...
            'gmaxca', gmax_ca, ...
            'ca_thresh', ca_thresh)),...
    'an',  struct());
ear = EarSumner2002(params);
```

The spike trains are submitted to a random refractory period
(fix term + random term).
If `ear.an.refractoriness` (defaults to `false`) was set to `true` before the run,
then another matrix of probabilities of firing is generated and saved in
`ear.an.prob_firing_refractory`.
This matrix shows the law of the Poisson process generating the spike trains,
which is to say, this each row represents the time histogram of an infinity of
spike trains after the random refractory period be applied.

- - - -

# Tests

Only tested on MacOS High Sierra 10.13.6

## Visualise model output

To run the model on a provided mp3 file, execute the below.
The resulting plot (saved in `tests/data/plots/`) shows the various matrices
derived as the information crosses the OME, the BM, ...
down to spike generation. The blue lines attempt to link the plots with 
their biophysical origination, with a zoom on the Organ of Corti 
(inside the cochlea).

```
cd tests/code/
visualisation_EarSumner2002()
```

![Input, intermediate matrices and output](https://bitbucket.org/allevity/pictures/raw/52ada86d861de9b73f134f2be6d9e9b3ff3cfc70/visualisation_EarSumner2002_wiki.jpg)
[1][2]

## Compare model versions

* Prerequisite:
The function `test_EarSumner2002_comparison_MAP_AN_only` assumes that
`MAP_AN_only.m` and `MAPparamsGP.m` are in Matlab's path.

To compare this implementation of the model with the former one,
execute the below.
Important variables will be checked 2-by-2 and a warning appears if there is a mismatch.

```
cd tests/code/
test_EarSumner2002_comparison_MAP_AN_only()
```
![Comparison between versions](https://bitbucket.org/allevity/pictures/raw/cd38a2a110053c72f6ca8e3b595bc6fc9b5c6a7e/test_EarSumner2002_comparison_MAP_AN_only.jpeg)

## Plot from original paper

To reproduce a plot from the paper showing the spiking rate of LSR/MSR/HSR fibers
of different best frequencies (250Hz to 24kHz) when reacting to sinusoids at this BF for
sound intensity varying between 0 and 100dB, execute the below.
Additionally, this compares the effect of previous the filter cascade (blue)
with the current one (red).
```
cd tests/code/
test_EarSumner2002()
```

![Low/Medium/High Spontaneous Rate fiber responses](https://bitbucket.org/allevity/pictures/raw/692e1c256e414a737e271a404464a3bf5e36f1aa/test_EarSumner2003.png)

- - - -

# Experiments:

## Speech recognition on neural data
* This part of the code expects HTK <http://htk.eng.cam.ac.uk/>
to be installed,
and various variables to be initialised.
* Set by launching
`
matlab/experiments/speech_recognition/experiment_launcher.m
`

# References:

Plots:

  * [1] By Lars Chittka; Axel Brockmann - Perception Space—The Final Frontier, A PLoS Biology Vol. 3, No. 4, e137 doi:10.1371/journal.pbio.0030137 (Fig. 1A/Large version), vectorised by Inductiveload, CC BY 2.5, https://commons.wikimedia.org/w/index.php?curid=5957984
  * [2] Henry Gray (1918) Anatomy of the Human Body, https://en.wikipedia.org/wiki/File:Gray931.png

External code sources:

  * Hash function (https://raw.githubusercontent.com/FNNDSC/matlab/master/misc/hash.m)
  * HTK functions: Mark Hasegawa-Johnson

 

