/*This macro asks for an input folder (directory), and file format (tif, jpg, etc). 
It opens each of the specified files in the folder, and asks you to selct Regions of interest (ROIs) around the mitochondria (or other areas of interest). 
The selected ROIs are saved as .zip files, to be used by the next macro
*/


input = getDirectory("Input directory"); //asks for folder where your image files are (path ends with a separator)
print("Input folder for ROI generation = " +input);

File.makeDirectory(input+"ROIs");
roiManager("reset"); //start with an empty ROI Manager so leftover ROIs are not saved with the first image
 
Dialog.create("File type");
Dialog.addString("File suffix: ", ".tif", 5);
Dialog.show();
suffix = Dialog.getString();

Dialog.create("Indicate Condition");
Dialog.addString("Experimental condition in this folder", "control or treatment?");
Dialog.show();
condition = Dialog.getString();

processFolder(input);

//Only the top-level folder is processed (no subfolders), to match EM-MitoMorphMacro,
//which reads ROIs from <input>/ROIs/ only. Use one folder per condition.
function processFolder(input) {
	list = getFileList(input);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + list[i]))
			continue;
		if(endsWith(list[i], suffix))
			//processFile(input, output, list[i]);
			processFile(input, list[i]);
	}
}

//function processFile(input, output, file) {
function processFile(input, file) {
	print("Processing: " + input + file);
	open(input+file);
	id = getImageID();
	title = getTitle();

	//image name = file name without the suffix (the window title can differ from the file name)
	image = substring(file, 0, lengthOf(file) - lengthOf(suffix));

	roiManager("reset");
	waitForUser("Select ROIs", "Select ROIs around mitochondria. \n Press t to save each one to the ROI Manager before slecting the next one. \n \n Press OK when you're done.");
	n=roiManager("count");
	if (n > 0) {
		roiManager("deselect");
		roiManager("Save", input+"ROIs"+File.separator+"ROIs-"+image+".zip");
		print("ROIs selected and saved for "+title+" : "+n+".");
	} else {
		print("No ROIs selected for "+title+" - skipped (no ROI file saved).");
	}
	roiManager("reset"); //safe when the ROI Manager is empty, unlike roiManager("delete")
	selectImage(id);
	close();
}


Dialog.create("Folder processing for ROIs finished!");
Dialog.addMessage("ROIs from all the images in the folder for <"+condition+"> have been generated and saved.");
Dialog.show();