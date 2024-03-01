## Integrating Verovio Into Flutter

- Cloning The Repo
- Installing Build Dependencies
- Building Correctly
- Creating New Flutter App And adding In Verovio
- Installing Flutter Dependencies
- Generating Bindings With FFIGen
- Using The Bindings / Weird Translation Things

## Cloning The Repo

Find their Github repo here: [Verovio Github Page](https://github.com/rism-digital/verovio).  I would suggest cloning their repo somewhere basic (and not in the directory of the flutter project itself).  This is because, once you build it, you only really need a few files to be taken away to certain places.  So once you build this, you can just delete the repo itself.  Personally, I just cloned to my Desktop, so I can see it easy and delete it fast when I need to.

## Installing Build Dependencies

The first thing you will need is Visual Studio installed, preferrably 2022 though I don't think it makes a difference.  Also make sure you have the "C++ Desktop Development" workload installed, as it includes various tools that you'll need later and for running and debugging in general.  You can make sure you have this through the Visual Studio Installer, and modifying your installation.

The second thing you need right now is some Make program.  You can either install [Make From Here](https://gnuwin32.sourceforge.net/packages/make.htm), or you can use NMake (which is what I used).  I'm not certain if I ended up installing NMake, or if I already had it as part of my existing toolkits, but you can try the build step and see if it lets you do it.  If not, using Make with the link mentioned may be the easiest.  I installed so many different things trying to get this stuff working that I don't remember how I landed on NMake.

## Building Correctly

The first step is to make sure that you are not in a normal terminal.  Go to your search bar for your computer, and start typing "x64".  One of the first things to pop up should be "x64 Native Tools Command Prompt for VS 2022".  Run this with admin rights.  For a few reasons, this whole process breaks in a few different points if you do any of this from a normal terminal.  To start, navigate to your local repo for verovio.  Then, run these commands starting at the base directory /verovio/

    cd tools
    cmake ../cmake -G "NMake Makefiles" -DBUILD_AS_LIBRARY=ON -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=TRUE -DNO_HUMDRUM_SUPPORT=ON
    nmake

This is assuming you do, in fact, have NMake.  If you got to the last step and found out that you don't, this is what I have seen works for those using Make

    cd tools
    cmake ../cmake -G "Unix Makefiles" -DBUILD_AS_LIBRARY=ON -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=TRUE -DNO_HUMDRUM_SUPPORT=ON
    make

Note: This does not mean that it builds for Unix.  The Make you install will take these and build for your system (I assume Windows x64).  When it's done (the final make step takes a good second to complete), you will see that the /tools/ directory has a verovio.dll as well as a number of other files.

## Creating New Flutter App And Adding In Verovio

The next step is to create the Flutter application that you want to interact with Verovio in.  I would strongly recommend that this isn't our team Gitlab repo.  I will integrate that in, given that I have a bit more experience with how it all works (I am also working on a nicer interface than what is discussed in the final section of this document).

Once you have the Flutter application created and open, create a new folder inside of /lib/ called whatever you want (though I would recommend "verovio").  Also create a folder outside of the /lib/ directory (root directory of project) called font_data.  The repo calls the same folder "data", but that's vague and it really only holds musical notation fonts.  Then, you will copy the following files into the following locations:

	Verovio Repo Path		--->	Flutter Library Path
	----------------------------------------------------
	/tools/verovio.dll		--->	/lib/verovio/
	/tools/c_wrapper.cpp	--->	/lib/verovio/
	/tools/c_wrapper.h		--->	/lib/verovio/
	/data/*					--->	/font_data/

For this last one, just take everything inside of the data folder, and slap it into the font_data folder.  There is one last step for this part and this is one of the steps that I have no idea why it's needed, but it sure is.  Open up the c_wrapper.h file, and add a newline under the #endif line, and add an include for stdbool like this

	#include <stdbool.h>

## Installing Flutter Dependencies

Now that we have a built .dll inside of our project with all the files it needs to thrive, we are ready to get Flutter ready to allow us to interact with it.  For this section, I am assuming you are in Visual Studio Code with the Flutter extension (That's where most recommend developing with Flutter, and it seems like we're all already using that).  Open a new terminal (can just be VS Code's terminal) and run these commands to install the tools we'll need:

	dart pub add -d ffigen
	winget install -e --id LLVM.LLVM

The second command will ask you to accept some terms, so just say "Y".  Once those are done, go into your project's pubspec.yaml file and add in the following settings at the bottom (the first line should be one tab indented):

	ffigen:
		output: 'lib/verovio/generated_bindings.dart'
		name: 'VerovioWrapper'
		description: 'Verovio C Library wrapper for Dart'
		functions:
			expose-typedefs:
				include:
					- '.*'
		headers:
			entry-points:
				- 'lib/verovio/c_wrapper.h'
			include-directives:
				- '**c_wrapper.h'
				- '**verovio.dll'
				- '**c_wrapper.cpp'

This is some information that is needed by the tool that helps us link the C wrapper interface to our Dart code.  And make sure to read through and change any paths that you may have set up differently than I did (for example, if you didn't name your verovio folder "verovio").

## Generating Bindings With FFIGen

Now we are ready to run the FFIGen tool.  But, whenever I run it from VS Code's terminal, it breaks.  So we go back to our trusty "x64 Native Tools Command Prompt for VS 2022".  From this terminal, navigate to the root directory of your Flutter application.  Run this command:

	dart run ffigen
	
If this finished without errors, you can skip the rest of this section.  If not, here is some info that may help.

If the error message quotes error message 193, that means that your dll and flutter sdk are mismatched; one is 32 bit and one is 64 bit.  The verovio library will be 32 bit unless you built it from the special terminal mentioned in the building section.  To check the version of your flutter sdk, do "dart --version".  If it says "windows_x64", your problem is that the dll is 32-bit.  Delete the dll, go into the verovio repo you cloned, go to /tools/, and delete the cmakeCache, cmakeFiles, and verovio.dll.  Restart at the build section in the special terminal.

If the error message quotes error message 123 (or somewhere in the 120's or 130's), the problem is that your path to your dll is incorrect.  Make sure that your path matches the dll's location.

## Using The Bindings / Weird Translation Things

Great, we got it building!  Now how do we use it?  At a high level, it is weird and requires use of type casting to get your inputs ready for C code, and to get the results ready for Dart code.  Here is my main.dart for my test application that calls a method or two from the library (creates an SVG for a blank piece of music which turns out to be an svg header).

	// ignore_for_file: avoid_print

	import 'dart:ffi';
	import 'dart:io';

	import 'package:ffi/ffi.dart';
	import 'package:flutter/material.dart';
	import 'package:path/path.dart';
	import 'package:verovio_integration/verovio/generated_bindings.dart';

	void dealWithLib() {
		print("Starting to deal with the lib");
		String path = absolute('lib', 'verovio', 'verovio.dll');
		print("Path to lib: $path");
		VerovioWrapper wrapper = VerovioWrapper(DynamicLibrary.open(path));
		print(wrapper);
	
		var ptr = wrapper.vrvToolkit_constructorResourcePath("font_data".toNativeUtf8().cast());
		var result = wrapper.vrvToolkit_renderToSVG(ptr, 1, true);
		print(result.cast<Utf8>().toDartString());
	}

	void main() {
		dealWithLib();
		runApp(const MainApp());
	}

	class MainApp extends StatelessWidget {
		const MainApp({super.key});

		@override
		Widget build(BuildContext context) {
			return const MaterialApp(
				home: Scaffold(
					body: Center(
					child: Text('Hello World!'),
					),
				),
			);
		}
	}

