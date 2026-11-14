input = getDirectory("Input directory"); //path ends with a separator
print("Input folder = " +input);
File.makeDirectory(input+"Count Masks");
run("Clear Results"); //start from an empty Results table so old rows are not mixed in
roiManager("reset");

Dialog.create("Indicate Condition");
Dialog.addString("Experimental condition in this folder", "control or treatment?");
Dialog.show();
condition = Dialog.getString();
 
Dialog.create("File type");
Dialog.addString("File suffix: ", ".tif", 5);
Dialog.show();
suffix = Dialog.getString();

processFolder(input);

//Only the top-level folder is processed (no subfolders), matching ROIBatchGen.
function processFolder(input) {
	list = getFileList(input);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + list[i]))
			continue;
		if(endsWith(list[i], suffix))
			processFile(input, list[i]);
	}
}

function processFile(input, file) {
	//image name = file name without the suffix (the window title can differ from the file name)
	image = substring(file, 0, lengthOf(file) - lengthOf(suffix));
	roiFile = input+"ROIs"+File.separator+"ROIs-"+image+".zip";
	if (!File.exists(roiFile)) {
		print(file+" skipped: no ROI file found ("+roiFile+").");
		return;
	}

	open(input+file);
	title = getTitle();
	print(title+ " is being processed.");

	//Process the images to increase contrast and remove BG
	run("Invert");
	run("Subtract Background...", "rolling=60");
	run("Subtract...", "value=100");
	run("Bandpass Filter...", "filter_large=60 filter_small=8 suppress=Vertical tolerance=5 autoscale saturate");

	//Threshold and make binary mask, fill in gaps in mask
	setAutoThreshold("MaxEntropy dark");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Dilate");
	run("Fill Holes");
	run("Dilate");
	run("Dilate");
	run("Dilate");
	run("Close-");
	run("Erode");
	run("Erode");
	run("Erode");
	run("Erode");
	run("Open");
	rename("Mask");

	//Open up the corresponding ROIs file for the image.
	//Duplicate out each ROI from the mask as a new image. Analyse those particles.
	roiManager("reset");
	roiManager("open", roiFile);
	run("Set Measurements...", "area perimeter fit shape feret's add redirect=None decimal=5");


	//Duplicate out each ROI from the mask as a new image. Analyse those particles. Generate count masks of those particles.
	n = roiManager("Count");
	for (i = 0; i < n; ++i) {
		m=i+1;
		selectWindow("Mask");
		roiManager("Select", i);
		roiName = call("ij.plugin.frame.RoiManager.getName", i);
		//run("Duplicate...", "title=Mask-"+i"");
		run("Duplicate...", " ");
		selectWindow("Mask-"+m+"");
		//run("Analyze Particles...", "size=500-Infinity circularity=0.40-1.00 show=[Overlay Masks] display exclude");
		firstRow = nResults;
 		run("Analyze Particles...", "size=600-Infinity pixel show=[Count Masks] display exclude"); //measures particles >600 pixels (the 'pixel' keyword keeps this in pixels even if the image is calibrated) - excludes remaining background
 		//label each new row so it can be traced back to its image and ROI (cell)
 		for (r = firstRow; r < nResults; r++) {
 			setResult("Condition", r, condition);
 			setResult("Image", r, image);
 			setResult("ROI", r, m);
 			setResult("ROIName", r, roiName);
 		}
 		updateResults();
	}
	saveAs("Results", input+condition+"-Results.csv"); //saves the results table with all the measurements for each particle in each ROI for each file processed so far.
	wait(1000);
	
	//Closes the ROI windows from an image. Saves the new count masks as tiffs
	for (i = 0; i < n; ++i) {
		m=i+1;		
		selectWindow("Mask-"+m+"");
		run("Close"); 	
		selectWindow("Count Masks of Mask-"+m+"");
		run("3-3-2 RGB");
		saveAs("tiff", input+"Count Masks"+File.separator+image+"-CountMask-"+m);
	}

	wait(1000);

	//clear and close the ROImanager and all open images
	roiManager("reset"); //safe when the ROI Manager is empty, unlike roiManager("delete")
	close("*");
}

//This section calculates parameters for mitochondrial morphology measurments, based on the measurements put out in the Results table

nParticles = nResults;
if (nParticles == 0) {
	print(condition+ ": no particles measured - summary not calculated.");
} else {
	sum_a = 0;        // sum of areas
	sum_a_sq = 0;     // sum of squared areas
	sum_p2_4pi = 0;   // sum of p^2 / (4*pi), numerator of the area-weighted form factor
	ff_sum = 0;       // sum of form factors
	ar_sum = 0;       // sum of aspect ratios

	for (i = 0; i < nParticles; i++) { // for every particle in table
		a = getResult("Area", i);
		p = getResult("Perim.", i);
		ar = getResult("Major", i) / getResult("Minor", i); /* aspect ratio = length / width */
		ff = (p*p) / (4 * PI * a); // ff = p^2 / (4 * pi * a)
		//setResult("AspectRatio", i, ar);
		setResult("FormFactor", i, ff);
		sum_a += a;
		sum_a_sq += a*a;
		sum_p2_4pi += (p * p) / (4 * PI);
		ff_sum += ff;
		ar_sum += ar;
	}
	updateResults();

	//average and output
	mean_a = sum_a / nParticles;
	a2 = (sum_a_sq / nParticles) / (mean_a * mean_a); // mean(a^2) / mean(a)^2 - does not depend on the number of particles
	awff = sum_p2_4pi / sum_a;                         // area-weighted form factor = sum(p^2/4pi) / sum(a) = sum(a*ff) / sum(a)
	mean_ff = ff_sum / nParticles;
	mean_ar = ar_sum / nParticles;

	print(condition+ " average measurements:" + "\t" + "nParticles" + "\t" + "Area" + "\t" + "Area2" + "\t" + "Area-WeightedFormFactor" + "\t" + "FormFactor" + "\t" + "AspectRatio");
	print(condition+ " average measurements:" + "\t" + nParticles + "\t" + mean_a + "\t" + a2 + "\t" + awff + "\t" + mean_ff + "\t" + mean_ar);
}

saveAs("Results", input+condition+"-Results with FF.csv"); //saves the results table with all the measurements for each particle in each ROI for each file in the folder.


//tidy up and confirm finished!
//run("Close"); 	//closes all image windows
close("Results");
close("ROI manager");
Dialog.create("Folder processing finished!");
	Dialog.addMessage("All the images in the folder for <"+condition+"> have been processed and analysed.");
	Dialog.show();


