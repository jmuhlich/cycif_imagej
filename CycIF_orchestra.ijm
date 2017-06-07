// @String sample_path
// @Integer num_cycles
// @Integer num_columns
// @Integer num_rows

run("Bio-Formats Macro Extensions");

// Load analyze script code.
analyze_filename = "analyze.js";
if (!File.exists(analyze_filename)) {
    exit("Can't find " + analyze_filename + ". Please change to the"
         + " directory containing the macro before running it.");
}
analyze_js_template = File.openAsString(analyze_filename);

//create "cycles" folder containing renamed .rcpnl files
print("=======");
print("STAGE 0");
print("=======");
in_dir = sample_path;
out_parent_dir = sample_path;
out_dir = out_parent_dir + "/" + "cycles";
File.makeDirectory(out_dir);
File.makeDirectory(out_parent_dir + "/" + "processing");
list = getFileList(in_dir);
// Quick check that this looks like a raw data directory.
ok = false;
for (raw=0; raw<list.length; raw++) {
    if (endsWith(list[raw], ".rcpnl")) {
	ok = true;
    }
}
if (!ok) {
    exit("The <sample_path> directory doesn't look like a raw data directory (no .rcpnl files).");
}
for (raw=0; raw<list.length; raw++) {
    showProgress(raw, list.length);
    title = list[raw];
    if (!endsWith(title, ".rcpnl")) {
        break;
    }
    if (startsWith(title, "1")) {
	filename = "cycle1_background.rcpnl";
    } else if (startsWith(title, "2")) {
	filename = "cycle1.rcpnl";
    } else if (startsWith(title, "3")) {
	filename = "cycle2_background.rcpnl";
    } else if (startsWith(title, "4")) {
	filename = "cycle2.rcpnl";
    } else if (startsWith(title, "5")) {
	filename = "cycle3_background.rcpnl";
    } else if (startsWith(title, "6")) {
	filename = "cycle3.rcpnl";
    } else if (startsWith(title, "7")) {
	filename = "cycle4_background.rcpnl";
    } else if (startsWith(title, "8")) {
	filename = "cycle4.rcpnl";
    }
    src_path = in_dir + "/" + title;
    dest_path = out_dir + "/" + filename;
    if (File.length(dest_path) == File.length(src_path)
        && File.lastModified(dest_path) >= File.lastModified(src_path)) {
        print("skipping (up-to-date) " + dest_path);
    } else {
        print("copying to " + dest_path);
        File.copy(src_path, dest_path);
    }
}

//
//
//

// Break out channels from each tile.
print("=======");
print("STAGE 2");
print("=======");
//
// (Previously step 1 was to break out tiles from the rcpnl files, but this
// was merged into step 2 for efficiency.)
in_dir = sample_path + "/cycles";
out_dir = sample_path + "/processing/2_channel_breakout";
File.makeDirectory(out_dir);

list = getFileList(in_dir);
setBatchMode(true);

for (cycle=0; cycle<list.length; cycle++) {
    filename = list[cycle];
    cycle_name = replace(filename, "\.rcpnl$", "");
    input_path = in_dir + "/" + filename;
    Ext.setId(input_path);
    Ext.getSeriesCount(series_length);
    if (cycle == 0) {
        // Sanity check.
        if (series_length != num_columns * num_rows) {
            exit("num_columns * num_rows must equal the total number of tiles (" + series_length + ").");
        }
    }
    Ext.getImageCount(num_channels);
    for (s=0; s<series_length; s++) {
        for (i=0; i<num_channels; i++) {
            output_filename = "c-" + (i+1) + "-" + num_channels + " - " + cycle_name + " " + (s+1) + ".tif";
            Ext.openImage("", i);
            saveAs("tiff", out_dir + "/" + output_filename);
            close();
        }
    }
    Ext.close();
}

//
//
//

//register channels of each tile
print("=======");
print("STAGE 3");
print("=======");
in_dir = sample_path + "/processing/2_channel_breakout";
out_dir = sample_path + "/processing/3_post_registration_images";
File.makeDirectory(out_dir);
File.makeDirectory(out_dir + "/" + "DAPI");
File.makeDirectory(out_dir + "/" + "FITC");
File.makeDirectory(out_dir + "/" + "Cy3");
File.makeDirectory(out_dir + "/" + "Cy5");
list = getFileList(in_dir);
setBatchMode(true);
for (tile=1; tile<=series_length; tile++){
	for (image=0; image<list.length; image++){
		showProgress(tile+1, list.length);
		if (endsWith(list[image], " " + tile + ".tif")){
		    path = in_dir + "/" + list[image];
		    print("opening " + path);
		    open(path);
		}
  }

run("Images to Stack", "name=DAPI title=c-1-4 use");
run("Images to Stack", "name=FITC title=c-2-4 use");
run("Images to Stack", "name=Cy3 title=c-3-4 use");
run("Images to Stack", "name=Cy5 title=c-4-4 use");

print("registering");
selectWindow("DAPI");
run("MultiStackReg", "stack_1=DAPI action_1=Align file_1=[" + sample_path + "/transformation_file2.txt] stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body] save");
selectWindow("FITC");
run("MultiStackReg", "stack_1=FITC action_1=[Load Transformation File] file_1=[" + sample_path + "/transformation_file2.txt] stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body]");
selectWindow("Cy3");
run("MultiStackReg", "stack_1=Cy3 action_1=[Load Transformation File] file_1=[" + sample_path + "/transformation_file2.txt] stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body]");
selectWindow("Cy5");
run("MultiStackReg", "stack_1=Cy5 action_1=[Load Transformation File] file_1=[" + sample_path + "/transformation_file2.txt] stack_2=None action_2=Ignore file_2=[] transformation=[Rigid Body]");

selectWindow("DAPI");
run("Stack to Images");
selectWindow("FITC");
run("Stack to Images");
selectWindow("Cy3");
run("Stack to Images");
selectWindow("Cy5");
run("Stack to Images");

imgArray = newArray(nImages);
  for (i=0; i<nImages; i++) {
    selectImage(i+1);
    title = getTitle();

    if (startsWith(title, "c-1")) {
    	intermediateDir = "DAPI";
    } else if (startsWith(title, "c-2")){
    	intermediateDir = "FITC";
    } else if (startsWith(title, "c-3")){
    	intermediateDir = "Cy3";
    } else if (startsWith(title, "c-4")){
    	intermediateDir = "Cy5";
    }
    finalIntermediate = out_dir + "/" + intermediateDir;
    finalFilename = finalIntermediate + "/" + title + ".tif";
    print("saving " + finalFilename);
    saveAs("tiff", finalFilename);
}
run("Close All");
}


//
//
//

//background subtraction
print("=======");
print("STAGE 4");
print("=======");
in_dir = sample_path + "/processing/3_post_registration_images";
out_dir = sample_path + "/processing/4_background_subtractions";
File.makeDirectory(out_dir);
list1 = getFileList(in_dir);
setBatchMode(true);
for (channel=0; channel<list1.length; channel++) {
	//print(list1[channel]);
	list2 = getFileList(in_dir + "/" + list1[channel]);
	//print(list2[0]);
	for (tile=1; tile<=series_length; tile++) {
		for (cycle=1; cycle<=num_cycles; cycle++) {
			for (ch=1; ch<=4; ch++){
				for (image=0; image<list2.length; image++) {
					if (endsWith(list2[image], " " + tile + ".tif")) {
						if (startsWith(list2[image], "c-" + ch + "-4 - " + "cycle" + cycle)) {
			    			//print(list2[image]);
			    			if (indexOf(list2[image], "background") >= 0) {
			    				//print(list2[image]);
			    				background = list2[image];
			    				signal = replace(background, "_background", "");
			    				print(signal);
			    				print(background);
			    				open(in_dir + "/" + list1[channel] + signal);
			    				open(in_dir + "/" + list1[channel] + background);
			    				if (ch != 1) {
			    				    imageCalculator("Subtract create", signal,background);
			    				}
			    				saveAs("Tiff", out_dir + "/" + "Result of " + signal);
			    			}
		    			}
	    			}
    			}
			}
		}
	}
}

in_dir = sample_path + "/processing/4_background_subtractions";
list = getFileList(in_dir);
setBatchMode(true);
for (BS=0; BS<list.length; BS++) {
	filename = list[BS];

  // EDITME Adjust antibody target names and filename components.

	if (startsWith(filename, "Result of c-2-4 - cycle1")) {
	    subdir = "BS-Ly6C";
	    open(in_dir + "/" + filename);
	    finalIntermediate = in_dir + "/" + subdir;
	    File.makeDirectory(finalIntermediate);
		finalFilename = finalIntermediate + "/" + filename;
		print("saving " + finalFilename);
		saveAs("tiff", finalFilename);
	} else if (startsWith(filename, "Result of c-3-4 - cycle1")) {
	  subdir = "BS-CD8a";
	  open(in_dir + "/" + filename);
	  finalIntermediate = in_dir + "/" + subdir;
	  File.makeDirectory(finalIntermediate);
	  finalFilename = finalIntermediate + "/" + filename;
	  print("saving " + finalFilename);
	  saveAs("tiff", finalFilename);
	} else if (startsWith(filename, "Result of c-4-4 - cycle1")) {
	  subdir = "BS-CD68";
	  open(in_dir + "/" + filename);
	  finalIntermediate = in_dir + "/" + subdir;
	  File.makeDirectory(finalIntermediate);
      finalFilename = finalIntermediate + "/" + filename;
	  print("saving " + finalFilename);
	  saveAs("tiff", finalFilename);
	} else if (startsWith(filename, "Result of c-2-4 - cycle2")) {
	  subdir = "BS-B220";
	  open(in_dir + "/" + filename);
	  finalIntermediate = in_dir + "/" + subdir;
	  File.makeDirectory(finalIntermediate);
	  finalFilename = finalIntermediate + "/" + filename;
	  print("saving " + finalFilename);
		saveAs("tiff", finalFilename);
	} else if (startsWith(filename, "Result of c-3-4 - cycle2")) {
	  subdir = "BS-CD4";
	  open(in_dir + "/" + filename);
	  finalIntermediate = in_dir + "/" + subdir;
	  File.makeDirectory(finalIntermediate);
	  finalFilename = finalIntermediate + "/" + filename;
	  print("saving " + finalFilename);
	  saveAs("tiff", finalFilename);
	} else if (startsWith(filename, "Result of c-4-4 - cycle2")) {
	  subdir = "BS-CD49b";
	  open(in_dir + "/" + filename);
	  finalIntermediate = in_dir + "/" + subdir;
	  File.makeDirectory(finalIntermediate);
	  finalFilename = finalIntermediate + "/" + filename;
	  print("saving " + finalFilename);
	  saveAs("tiff", finalFilename);
	} else if (startsWith(filename, "Result of c-2-4 - cycle3")) {
	  subdir = "BS-FOXP3";
	  open(in_dir + "/" + filename);
	  finalIntermediate = in_dir + "/" + subdir;
	  File.makeDirectory(finalIntermediate);
	  finalFilename = finalIntermediate + "/" + filename;
	  print("saving " + finalFilename);
	  saveAs("tiff", finalFilename);
	} else if (startsWith(filename, "Result of c-4-4 - cycle3")) {
	  subdir = "BS-CD11b";
	  open(in_dir + "/" + filename);
	  finalIntermediate = in_dir + "/" + subdir;
	  File.makeDirectory(finalIntermediate);
	  finalFilename = finalIntermediate + "/" + filename;
	  print("saving " + finalFilename);
	  saveAs("tiff", finalFilename);
  } else if (startsWith(filename, "Result of c-3-4 - cycle3")) {
	  subdir = "BS-VIMENTIN";
	  open(in_dir + "/" + filename);
	  finalIntermediate = in_dir + "/" + subdir;
	  File.makeDirectory(finalIntermediate);
	  finalFilename = finalIntermediate + "/" + filename;
	  print("saving " + finalFilename);
	  saveAs("tiff", finalFilename);
  } else if (startsWith(filename, "Result of c-1-4 - cycle3")) {
    subdir = "BS-DAPI";
    open(in_dir + "/" + filename);
    finalIntermediate = in_dir + "/" + subdir;
    File.makeDirectory(finalIntermediate);
    finalFilename = finalIntermediate + "/" + filename;
    print("saving " + finalFilename);
    saveAs("tiff", finalFilename);
	}
}

//
//
//

//generate target montages
print("=======");
print("STAGE 5");
print("=======");
in_dir = sample_path + "/processing/4_background_subtractions";
out_dir = sample_path + "/processing/5_target_montages";
File.makeDirectory(out_dir);
list = getFileList(in_dir);
setBatchMode(true);
for (folder=0; folder<list.length; folder++) {
	if (startsWith(list[folder], "BS")) {
		//print(list[folder]);
		open(in_dir + "/" + list[folder]);
		run("Flip Vertically", "stack");
		run("Make Montage...", "columns=" + num_columns + " rows=" + num_rows + " scale=1");
		rename(list[folder] + "montage");
		imgArray=newArray(nImages);
    	for (i=0;i<nImages;i++) {
        	selectImage(i+1);
        	title = getTitle();
        	title = replace(title, '[/]', '-');
    	}
		if (endsWith(title, "montage")) {
		    finalFilename = out_dir + "/" + title;
        run("Flip Vertically");
			print("saving " + finalFilename);
			saveAs("tiff", finalFilename);
		}
		run("Close All");
	}
}


//
//
//

/*
// Commented out because this all depends on manual adjustment.

//adjust brightness and contrast (MUST DO BY HAND!!!)
print("=======");
print("STAGE 6");
print("=======");
in_dir = sample_path + "/processing/5_target_montages";
out_dir = sample_path + "/processing/6_brightness_and_contrast_corrections";
File.makeDirectory(out_dir);
list = getFileList(in_dir);
setBatchMode(false);
for (montage=0; montage<list.length; montage++) {
	open(in_dir + "/" + list[montage]);
}

//
//
//

//save B&C montages
out_dir = sample_path + "/processing/6_brightness_and_contrast_corrections";
imgArray=newArray(nImages);
    	for (i=0;i<nImages;i++) {
        	selectImage(i+1);
        	title = getTitle();
          	rename("B&C-" + title);
          	title = getTitle();
        	print("saving " + title);
			saveAs("Tiff", out_dir + "/" + title);
    	}
		 run("Close All");

//
//
//

//make RGB
print("=======");
print("STAGE 7");
print("=======");
in_dir = sample_path + "/processing/6_brightness_and_contrast_corrections";
out_dir = sample_path + "/processing/7_RGB_color_images"
File.makeDirectory(out_dir);
list = getFileList(in_dir);
setBatchMode(true);
for (montage=0; montage<list.length; montage++) {
	open(in_dir + "/" + list[montage]);
}

imgArray=newArray(nImages);
// EDITME Adjust colors and channel match strings.
for (i=0;i<nImages;i++) {
    selectImage(i+1);
    title = getTitle();
    showProgress(i+1, nImages);
    if (startsWith(title, "B&C-BS-DAPI")) {
		    run("GRAY");
		    run("RGB Color");
		    print("saving " + out_dir + "/" + title);
		    saveAs("Tiff", out_dir + "/" + title);
	  } else if (startsWith(title, "B&C-BS-Ly6C")) {
			  run("ORANGE");
			  run("RGB Color");
			  print("saving " + out_dir + "/" + title);
			  saveAs("Tiff", out_dir + "/" + title);
	  } else if (startsWith(title, "B&C-BS-CD68")) {
			  run("CYAN");
			  run("RGB Color");
			  print("saving " + out_dir + "/" + title);
			  saveAs("Tiff", out_dir + "/" + title);
	  } else if (startsWith(title, "B&C-BS-CD49b")) {
			  run("WHITE");
			  run("RGB Color");
			  print("saving " + out_dir + "/" + title);
			  saveAs("Tiff", out_dir + "/" + title);
	  } else if (startsWith(title, "B&C-BS-CD11b")) {
			  run("GREEN");
			  run("RGB Color");
			  print("saving " + out_dir + "/" + title);
			  saveAs("Tiff", out_dir + "/" + title);
	  } else if (startsWith(title, "B&C-BS-CD8a")) {
			  run("YELLOW");
			  run("RGB Color");
			  print("saving " + out_dir + "/" + title);
			  saveAs("Tiff", out_dir + "/" + title);
	  } else if (startsWith(title, "B&C-BS-CD4")) {
			  run("RED");
			  run("RGB Color");
			  print("saving " + out_dir + "/" + title);
			  saveAs("Tiff", out_dir + "/" + title);
	  } else if (startsWith(title, "B&C-BS-B220")) {
			  run("MAGENTA");
			  run("RGB Color");
			  print("saving " + out_dir + "/" + title);
			  saveAs("Tiff", out_dir + "/" + title);
  	} else if (startsWith(title, "B&C-BS-Ly6G")) {
  			run("BROWN");
  			run("RGB Color");
  			print("saving " + out_dir + "/" + title);
  			saveAs("Tiff", out_dir + "/" + title);
  	} else if (startsWith(title, "B&C-BS-Foxp3")) {
  			run("BLUE");
  			run("RGB Color");
  			print("saving " + out_dir + "/" + title);
  			saveAs("Tiff", out_dir + "/" + title);
    } else if (startsWith(title, "B&C-BS-VIMENTIN")) {
  			run("VIOLET");
  			run("RGB Color");
  			print("saving " + out_dir + "/" + title);
  			saveAs("Tiff", out_dir + "/" + title);
  	}
}

//
//
//

//generate montage final image
File.makeDirectory("/Users/gregbaker/Desktop/brain_CycIF_7/processing/8_final_image");
File.makeDirectory("/Users/gregbaker/Desktop/brain_CycIF_7/processing/9_intaglio_figure");
in_dir = "/Users/gregbaker/Desktop/brain_CycIF_7/processing/7_RGB_color_images";
setBatchMode(true);
out_dir = "/Users/gregbaker/Desktop/brain_CycIF_7/processing/8_final_image"
run("Image Sequence...", "open=[" + in_dir + "] sort");
run("Z Project...", "projection=[Max Intensity]");
saveAs("Tiff", out_dir + "/" + "final.tif");
run("Close All");

// End block depending on manual
*/

//
//
//


//get each registered and merged tile for segmentation
print("========");
print("STAGE 10");
print("========");
in_dir = sample_path + "/processing/4_background_subtractions";
out_parent_dir = sample_path + "/processing/10_tiles_for_segmentation";
File.makeDirectory (out_parent_dir);
list1 = getFileList(in_dir);
setBatchMode(true);
for (tile=0; tile<series_length; tile++) {
	showProgress(tile, series_length);
    out_dir = out_parent_dir + "/" + (tile+1) + "/" + "BS";
	File.makeDirectory (out_parent_dir + "/" + (tile+1));
	File.makeDirectory (out_dir);
	for (channel=0; channel<list1.length; channel++) {
		if (startsWith(list1[channel], "BS")) {
			list2 = getFileList(in_dir + "/" + list1[channel]);
			open(in_dir + "/" + list1[channel] + "/" + list2[tile]);
			imgArray=newArray(nImages);
    			for (i=0;i<nImages;i++) {
        			selectImage(i+1);
        			title = getTitle();
        			if (startsWith(title, "Result of c-2-4 - cycle2")) {
        				rename("B220");
        				title = "B220.tif";
        			} else if (startsWith(title, "Result of c-4-4 - cycle3")) {
        				rename("CD11b");
        				title = "CD11b.tif";
        			} else if (startsWith(title, "Result of c-3-4 - cycle2")) {
        				rename("CD4");
        				title = "CD4.tif";
        			} else if (startsWith(title, "Result of c-3-4 - cycle1")) {
        				rename("CD8a");
        				title = "CD8a.tif";
        			} else if (startsWith(title, "Result of c-4-4 - cycle2")) {
        				rename("CD49b");
        				title = "CD49b.tif";
        			} else if (startsWith(title, "Result of c-4-4 - cycle1")) {
        				rename("CD68");
        				title = "CD68.tif";
        			} else if (startsWith(title, "Result of c-1-4 - cycle4")) {
        				rename("DAPI");
        				title = "DAPI.tif";
        			} else if (startsWith(title, "Result of c-2-4 - cycle3")) {
        				rename("Foxp3");
        				title = "Foxp3.tif";
        			} else if (startsWith(title, "Result of c-2-4 - cycle1")) {
        				rename("Ly6C");
        				title = "Ly6C.tif";
        			} else if (startsWith(title, "Result of c-3-4 - cycle3")) {
        				rename("VIMENTIN");
        				title = "VIMENTIN.tif";
        			}
    			}
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
		}
	}
}

//
//
//

//adjust B&C per channel to match respective montages
in_dir1 = sample_path + "/processing/10_tiles_for_segmentation";
list1 = getFileList(in_dir1);
setBatchMode(true);
for (tile=0; tile<list1.length; tile++) {
		in_dir2 = sample_path + "/processing/10_tiles_for_segmentation" + "/" + list1[tile] + "/" + "BS";
      //showProgress(tile+1, list1.length);
		list2 = getFileList(in_dir2);
		File.makeDirectory(in_dir1 + "/" + list1[tile] + "/" + "B&C");
		out_dir = in_dir1 + "/" + list1[tile] + "B&C";

    // EDITME min/max values

		for (channel=0; channel<list2.length; channel++) {
			//print(in_dir + "/" + list1[tile] + list2[channel]);
			if (startsWith(list2[channel], "CD49b")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(1883, 6995);
				run("Grays"); // FIXME was WHITE -- is this ok?
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "B220")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(1844, 8840);
				run("Magenta");
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "CD4")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(0, 8263);
				run("Red");
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "CD8a")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(606, 16218);
				run("Yellow");
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "CD11b")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(25983, 38782);
				run("Green");
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "CD68")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(2492, 18088);
				run("Cyan");
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "DAPI")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(0, 1458);
				run("Grays"); // FIXME how is GRAY different from WHITE?
				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "Foxp3")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(607, 3799);
				run("Blue");
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "Ly6C")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(0, 38839);
				run("ORANGE");
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "Ly6G")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(1200, 8390);
				run("BROWN");
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
			} else if (startsWith(list2[channel], "VIMENTIN")) {
				//print(in_dir + "/" + list1[tile] + list2[channel]);
				open(in_dir2 + "/" + list2[channel]);
				setMinAndMax(63796, 63796);
				run("VIOLET");
  				run("RGB Color");
				title = getTitle();
    			print("saving " + out_dir + "/" + title);
    			saveAs("Tiff", out_dir + "/" + title);
    		}
    	}
}

//
//
//

//generate individual final images
in_dir1 = sample_path + "/processing/10_tiles_for_segmentation";
list1 = getFileList(in_dir1);
setBatchMode(true);
for (tile=0; tile<list1.length; tile++) {
		in_dir2 = sample_path + "/processing/10_tiles_for_segmentation" + "/" + list1[tile] + "/" + "B&C";
      	showProgress(tile+1, list1.length);
		list2 = getFileList(in_dir2);
		File.makeDirectory(in_dir1 + "/" + list1[tile] + "/" + "final");
		out_dir = in_dir1 + "/" + list1[tile] + "final";
		run("Image Sequence...", "open=[" + in_dir2 + "] sort");
		run("Z Project...", "projection=[Max Intensity]");
		saveAs("Tiff", out_dir + "/" + "final.tif");
		run("Close All");
}

//
//
//


//generate single-cell data from each tile
print("========");
print("STAGE 11");
print("========");
File.makeDirectory (sample_path + "/processing/11_segmentation_results");
DAPI_dir = sample_path + "/processing/3_post_registration_images/DAPI";
bs_base_dir = sample_path + "/processing/4_background_subtractions/";
bs_dirs = getFileList(bs_base_dir);
bs_files = newArray();
for (i=0; i<bs_dirs.length; i++) {
    dir = bs_dirs[i];
    if (!endsWith(dir, "DAPI/") && endsWith(dir, "/")) {
    	sub_dir = bs_base_dir + dir;
        dir_files = getFileList(sub_dir);
        for (j=0; j<dir_files.length; j++) {
        	dir_files[j] = sub_dir + dir_files[j];
        }
        bs_files = Array.concat(bs_files, dir_files);
    }
}

for (tile=1; tile<=series_length; tile++) {
	print("-> tile ", tile);
    showProgress(tile-1, series_length);
		out_dir = sample_path + "/processing/11_segmentation_results" + "/" + tile;
    File.makeDirectory(out_dir);

    // Open all DAPI-channel images. Do it in cycle order so the current image
    // after the loop terminates is the last cycle image.
    for (cycle=1; cycle<=num_cycles; cycle++) {
        dapi_image = DAPI_dir + "/" + "c-1-4 - cycle" + cycle + " " + tile + ".tif";
  	open(dapi_image);
        run("Gaussian Blur...", "sigma=2");
  	run("Subtract Background...", "rolling=5 sliding");
    }
    // Now, the current image is the last DAPI channel. Duplicate it and build a
    // mask for the nuclei of the remaining cells in this tile.
    run("Duplicate...", "title=mask");
    run("Make Binary");
    run("Watershed");
    run("Analyze Particles...", "size=20-3000 pixel circularity=0.10-1.00 show=Overlay exclude clear include");
    for (j=0; j<Overlay.size; j++) {
        Overlay.activateSelection(0);
        run("Enlarge...", "enlarge=3 pixel");
        Overlay.addSelection();
        Overlay.removeSelection(0);
    }

    for (i=0; i<bs_files.length; i++) {
        filename = bs_files[i];
        if (endsWith(filename, " " + tile + ".tif")) {
            open(filename);
            run("Gaussian Blur...", "sigma=2");
  	    run("Subtract Background...", "rolling=5 sliding");
        }
    }

    out_path = out_dir + "/" + "segmentation_results" + tile + ".tsv";
    analyze_js = replace(analyze_js_template, "\\$OUTPUT_PATH", out_path);
    eval("script", analyze_js);
    run("Close All");
}

//
//
//

//generate single-cell data from each tile (IF USING THRESHELD IMAGES!!)
/*
out_parent_dir = sample_path + "/processing/11_segmentation_results";
File.makeDirectory (out_parent_dir);
DAPI_dir = sample_path + "/processing/3_post_registration_images/DAPI";
in_dir1 = sample_path + "/processing/10_tiles_for_segmentation" + "/" + "1" + "/" + "B&C";
list = getFileList(in_dir1)
setBatchMode(true);
for (tile=1; tile<=series_length; tile++) {
      showProgress(tile, series_length);
			in_dir2 = sample_path + "/processing/10_tiles_for_segmentation" + "/" + tile + "/" + "B&C";
			print(in_dir2);

	File.makeDirectory (out_parent_dir + "/" + tile);
	out_dir = out_parent_dir + "/" + tile;
	for (cycle=1; cycle<=num_cycles; cycle++) {
			open(DAPI_dir + "/" + "c-1-4 - cycle" + cycle + " " + tile + ".tif");
	}

     imgArray=newArray(nImages);
    	for (i=0;i<nImages;i++) {
        	selectImage(i+1);
        	title = getTitle();
    	}
     if (startsWith(title, "c-1-4 - cycle4" + " " + tile + ".tif")) {
    		run("Gaussian Blur...", "sigma=2");
    		run("Subtract Background...", "rolling=5 sliding");
    		run("Duplicate...", " ");
    		rename("mask" + tile);
    		run("Make Binary");
    		run("Watershed");
    		run("Analyze Particles...", "size=20-3000 pixel circularity=0.10-1.00 show=Outlines exclude clear include add in_situ");
        counts=roiManager("count");
				for(i=0; i<counts; i++) {
					roiManager("Select", i);
					run("Enlarge...", "enlarge=3 pixel");
					roiManager("Update");
				}
				roiManager("Deselect");
	}

  for (cycle=1; cycle<=num_cycles; cycle++) {
 		selectWindow("c-1-4 - cycle" + cycle + " " + tile + ".tif");
  	run("Gaussian Blur...", "sigma=2");
  	run("Subtract Background...", "rolling=5 sliding");
  	run("From ROI Manager");
  	roiManager("Measure");
  }
  run("Close All");

  open(in_dir2 + "/" + "B220.tif");
	open(in_dir2 + "/" + "CD4.tif");
	open(in_dir2 + "/" + "CD8a.tif");
	open(in_dir2 + "/" + "CD11b.tif");
	open(in_dir2 + "/" + "CD49b.tif");
	open(in_dir2 + "/" + "CD68.tif");
	open(in_dir2 + "/" + "Foxp3.tif");
	open(in_dir2 + "/" + "Ly6C.tif");
	open(in_dir2 + "/" + "VIMENTIN.tif");

	imgArray=newArray(nImages);
    	for (i=0;i<nImages;i++) {
        	selectImage(i+1);
        	title = getTitle();
    		run("Gaussian Blur...", "sigma=2");
    		run("Subtract Background...", "rolling=5 sliding");
    		run("From ROI Manager");
    		roiManager("Measure");
    	}
	roiManager("Delete");
	run("Close All");
	saveAs("Results", out_dir + "/" + "segmentation_results" + tile + ".xls");
}
*/
