from __future__ import division
import sys
import re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
#import seaborn as sns
import pathlib2 as pathlib


base = pathlib.Path(sys.argv[1])
dfs = []
for sample_path in base.iterdir():
    sample_name = sample_path.name
    if not re.match(r'\d+_\w+_\d+', sample_name):
        continue
    # Only load a subset of the data for now.
    if not sample_name in ('26_NAIVE_2', '23_TUMOR_3'):
        continue
    print sample_name
    results_path = sample_path.joinpath('processing', '11_segmentation_results')
    for i, tile_path in enumerate(results_path.iterdir()):
        print '\r  ', i,
        sys.stdout.flush()
        tile_num = int(tile_path.name)
        filename = 'segmentation_results%d.tsv' % tile_num
        df = pd.read_table(str(tile_path.joinpath(filename)))
        (day, tissue, replicate) = sample_name.split('_')
        df['sample_name'] = sample_name
        df['day'] = int(day)
        df['tissue'] = tissue
        df['replicate'] = int(replicate)
        df['tile'] = tile_num
        dfs.append(df)
    print

data = pd.concat(dfs)
del dfs
data.rename(columns={' ': 'object'}, inplace=True)

data['tile_x'] = (data.tile - 1) % 11
data['tile_y'] = (data.tile - 1) // 11
data['gx'] = data.tile_x * (1280*.325) + data.X
data['gy'] = (data.tile_y + 1) * (1080*.325) - data.Y

ab_channels = [
    'c-2-4 - cycle1', 'c-3-4 - cycle1', 'c-4-4 - cycle1',
    'c-2-4 - cycle2', 'c-3-4 - cycle2', 'c-4-4 - cycle2',
    'c-2-4 - cycle3', 'c-3-4 - cycle3', 'c-4-4 - cycle3',
]
ab_names = [
    'LY6C', 'CD8', 'CD68', 'B220', 'CD4', 'CD49B', 'CD11B', 'FOXP3', 'VIMENTIN',
]
data['readout'] = (
    data.Label
    .replace([r' \d+\.tif$', '^Result of '], '', regex=True)
    .replace(['c-1-4 - cycle'], ['DAPI-'], regex=True)
    .replace(ab_channels, ab_names)
)
del data['Label']
data.reset_index(drop=True, inplace=True)

#data.set_index(['sample_name', 'tile', 'object', 'readout'], inplace=True)
#data = data.unstack(level='readout')

dmean = data[['tissue', 'day', 'replicate', 'object', 'readout', 'Mean']]

plt.ion()

colors = {'TUMOR': 'orange', 'NAIVE': 'lightblue'}
readouts = dmean.readout.unique()
ncols = int(np.ceil(len(readouts) ** 0.5))
nrows = int(np.ceil(len(readouts) / ncols))
fig, axes = plt.subplots(ncols, nrows)
axes = axes.flatten()
for readout, ax in zip(readouts, axes):
    dmr = dmean[dmean.readout==readout]
    brange = np.percentile(dmr.Mean, [0.01, 99.9])
    bins = np.linspace(brange[0], brange[1], 100)
    g = dmr.groupby(['tissue'])
    for tissue, idx in g.groups.items():
        ax.hist(dmr.Mean[idx], bins=bins, histtype='step', label=tissue,
                color=colors[tissue], lw=1, log=True)
        ax.set_title(readout)
        ax.set_ylim(ymin=1)
axes[-1].legend()
plt.tight_layout(1.0)

x = data[(data.sample_name=='23_TUMOR_3')&(data.readout=='CD68')]
plt.subplot(121)
plt.imshow(np.flipud(skimage.transform.rescale(im, 0.1)), cmap='gray')
plt.xlim(0, 1400)
plt.ylim(0, 1700)
plt.subplot(122)
plt.scatter(x.gx/10/.325, x.gy/10/.325, s=x.Area/10, alpha=0.1)
plt.xlim(0, 1400)
plt.ylim(0, 1700)
plt.gca().set_aspect('equal')
