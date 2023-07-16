#@String inputFolder

run("Close All");
run("Clear Results");
roiManager("reset");
maskExt = "_Mask.tif";
CD31Channel = 2;
CD105Channel = 3;
setBatchMode("hide");

///////////////////////////////////////////////////////////////

list = getFileList(inputFolder);


for (ik=list.length-1; ik>=0; ik--){ // for loop to parse through files in main folder 
	if(!endsWith(list[ik], maskExt)){   // if the filename does not end with correct part, pop it from the list
		list = Array.deleteIndex(list, ik);
	}
}
/////////////////////////////////////////////////////////////////////
print(inputFolder+"==> "+list.length+" set of images to treat");

for (ik=0; ik<list.length; ik++){ // for loop to parse through names in main folder 
	// Generic information
	
	currentFile=inputFolder+list[ik];

	GlobalName = substring(list[ik],0,lengthOf(list[ik]) - lengthOf(maskExt));
	filename = inputFolder + GlobalName + maskExt;
	outputCD31segfilename = inputFolder + "Quantification/" + GlobalName + "_CD31_AnalyzeParticles.txt";
	outputCD105segfilename = inputFolder + "Quantification/" + GlobalName + "_CD105_AnalyzeParticles.txt";
	
	print("File "+(ik+1)+" of " + list.length + " in process: "+GlobalName);


	// Open the mask file
	open(filename);
	NameMaskImage = getTitle();

	// ONLY IMPORT CD31 CHANNEL
	run("Bio-Formats Importer", "open=["+filename_ECs+"] specify_range view=Hyperstack stack_order=XYCZT c_begin=" + CD31Channel + " c_end=" + CD31Channel + " c_step=1");
	rename("C" + CD31Channel + "-multichannel");
	NameImageCD31 = getTitle();
	selectWindow(NameMaskImage);
	//run("Threshold...");
	setThreshold(128, 255);
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Create Selection");
	
	// overlaying mask with CD31 
	selectWindow(NameImageCD31);
	run("Restore Selection");
	run("Clear Outside");
	//run("Set Measurements...", "area redirect=None decimal=2");
	//run("Measure");
	//saveAs("Results", outputAreasegfilename); // Saving the total cross-sectional area
	//run("Clear Results");
	/////////////////
	roiManager("reset");
	run("Select None");
	run("Duplicate...", "title=maskCD31");
	run("Restore Selection");
	run("Gaussian Blur...", "sigma=1");
	setAutoThreshold("Li dark");
	//run("Threshold...");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	//run("Convert to Mask");
	run("Fill Holes");
	run("Watershed");
	//rename("TheROIs");
	NameROI = getTitle();
	run("Set Measurements...", "area mean standard modal min center shape median display redirect=["+NameImageCD31+"] decimal=3");
	run("Analyze Particles...", "size=1-Infinity show=Outlines display include add");
	saveAs("Results", outputCD31segfilename);
	run("Clear Results");
	
	// ONLY IMPORT CD105 CHANNEL
	run("Bio-Formats Importer", "open=["+filename_ECs+"] specify_range view=Hyperstack stack_order=XYCZT c_begin=" + CD105Channel + " c_end=" + CD105Channel + " c_step=1");
	rename("C" + CD105Channel + "-multichannel");
	NameImageCD105 = getTitle();
		
	// overlaying mask with CD105
	selectWindow(NameMaskImage);
	run("Scale...", "width="+width+" height="+height+" interpolation=Bilinear average create");
	//run("Threshold...");
	setThreshold(128, 255);
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Create Selection");
	selectWindow(NameImageCD105);
	run("Restore Selection");
	run("Clear Outside");

	selectWindow(NameImageCD105);
	run("Gaussian Blur...", "sigma=1");
	setAutoThreshold("Li dark");
	//run("Threshold...");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	//run("Convert to Mask");
	run("Fill Holes");
	selectWindow(NameROI);
	run("Set Measurements...", "area mean standard modal min center shape median display redirect=["+NameImageCD105+"] decimal=3");
	run("Analyze Particles...", "size=1-Infinity show=Outlines display include add");
	saveAs("Results", outputCD105segfilename);
	run("Clear Results");
	roiManager("reset");
	run("Close All");
	
}
print("Finished processing");

setBatchMode("show");

//eval("script", "System.exit(0);");