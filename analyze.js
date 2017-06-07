/* ImageJ's macro functionality for feature analysis with ROIs/overlays is not
 * compatible with headless mode, as it contains implicit calls to create GUI
 * objects such as the ROI manager and Result Table. Therefore the entire
 * sequence from analysis to writing the output file must take place in a
 * script which uses the internal Java API.
 *
 * This script expects as input the following state:
 * - An image titled "mask" with an overlay. This overlay defines the ROIs to
 *   be measured.
 * - A series of other images to be analyzed using the overlay ROIs.
 *
 * The output is written to a TSV file. The output file path is encoded in this
 * script as $OUTPUT_PATH -- this token must be replaced with the actual path
 * via string replacement (e.g. the 'replace' macro function) before executing
 * the code.
 *
 * This script should not close any open images or other windows, but it must
 * call .hide on any images with an ROI before exiting. Otherwise there will be
 * a HeadlessException when the calling macro closes the windows due to some
 * internal issues in the core ImageJ code.
 */


importClass(Packages.java.io.FileWriter);
importClass(Packages.java.io.BufferedWriter);

var mask = WindowManager.getImage('mask');
var overlay = mask.getOverlay();
// Hide, don't close, as explained above.
mask.hide();

var n = WindowManager.getImageCount();
var measurements = Measurements.ALL_STATS | Measurements.LABELS;
// We'll store each image's results in a separate table, so the object indexing
// resets to 1 for each image.
var tables = new Array();

// Measure all ROIs in all open images.
for (var i=1; i<=n; i++) {
    var img = WindowManager.getImage(i);
    var rt = new ResultsTable();
    tables.push(rt);
    var analyzer = new Analyzer(img, measurements, rt);
    print('analyzing image: ' + img.getTitle());
    for (var r=0; r<overlay.size(); r++) {
        var roi = overlay.get(r);
        img.setRoi(roi);
        analyzer.measure();
    }
}

/* As noted above, ImageJ crashes in headless mode when closing windows whose
 * images have an ROI set (as all of our images here do). The workaround is to
 * first call .hide on them.
 */
for (i=1; i<=n; i++) {
    /* The '1' argument is not a typo -- hidden images are removed from the list
     * of active images, so we just keep hiding the first image to effectively
     * iterate over all of them.
     */
    var img = WindowManager.getImage(1);
    img.hide();
}

var writer = new BufferedWriter(new FileWriter('$OUTPUT_PATH'));
// Write one header for the file (all tables should have the same headings).
writer.write(tables[0].getColumnHeadings());
writer.newLine();
for (var i=0; i<tables.length; i++) {
    rt = tables[i];
    for (var r=0; r<rt.size(); r++) {
        writer.write(rt.getRowAsString(r));
        writer.newLine();
    }
}
writer.close();
