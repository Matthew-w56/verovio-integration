# Installing Verovio to Your Machine

This is a quick guide for how to install Verovio to your machine to make the code in this project work.  Quick note: This is meant for Windows 10.  If that isn't the system you are using, the steps still apply but will have differences in syntax.  And don't worry; as hard as it kicked my butt as I tried to get this working the first time, the instructions aren't too hard to follow.  Here's the general steps that we will follow:

- [Clone The Verovio Repository](#cloning-the-verovio-repository)
- [Installing Any Tools We Need](#installing-any-tools-we-need)
- [Calling The Build Commands For Verovio](#calling-the-build-commands-for-verovio)
- [Installing Verovio Into Our System](#installing-verovio-into-our-system)

## Cloning The Verovio Repository

Cclone their repository from: [Verovio github page](https://github.com/rism-digital/verovio) (Command below, so the link is just if you want to see it).  I would suggest cloning their repo somewhere basic (and not in the directory of the flutter project itself).  This is because, once you build it, you don't need to keep their repository around.  So once you build this, you can just delete the repo itself.  Personally, I just cloned to my Desktop, so I can see it easy and delete it fast when I need to.  Also, if you happen to notice that this is the "develop" branch rather than the "master", don't worry.  That is the branch they do all their work on, and is kept stable at all times.

  git clone https://github.com/rism-digital/verovio.git

## Installing Any Tools We Need

The first thing you will need is Visual Studio installed, preferrably 2022 though I don't think it makes a difference.  Also make sure you have the "C++ Desktop Development" workload installed, as it includes various tools that you'll need later and for running and debugging in general.  You can make sure you have this through the Visual Studio Installer, and modifying your installation.

The second thing you need right now is some Make program.  You can either install [Make From Here](https://gnuwin32.sourceforge.net/packages/make.htm), or you can use NMake (which is what I used).  I'm not certain if I ended up installing NMake, or if I already had it as part of my existing toolkits, but you can try the build step and see if it lets you do it.  If not, using Make with the link mentioned may be the easiest.  I installed so many different things trying to get this stuff working that I don't remember how I landed on NMake.

## Calling The Build Commands For Verovio

The first step is to make sure that you are **_NOT_** in a normal terminal.  Go to your search bar for your computer, and start typing "x64".  One of the first things to pop up should be "x64 Native Tools Command Prompt for VS 2022".  Run this with admin rights.  For a few reasons, this whole process breaks in a few different points if you do any of this from a normal terminal.  To start, navigate to your local repo for verovio.  Then, run these commands starting at the base directory /verovio/

    cd tools
    cmake ../cmake -G "NMake Makefiles" -DBUILD_AS_LIBRARY=ON -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=TRUE -DNO_HUMDRUM_SUPPORT=ON
    nmake
    nmake install

This is assuming you do, in fact, have NMake.  If you got to the last step and found out that you don't, this is what I have seen works for those using Make

    cd tools
    cmake ../cmake -G "Unix Makefiles" -DBUILD_AS_LIBRARY=ON -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=TRUE -DNO_HUMDRUM_SUPPORT=ON
    make
    make install

Note: This does not mean that it builds for Unix.  The Make you install will take these and build for your system (I assume Windows x64).  When it's done (the main build command takes a good second to complete), you will see that the /tools/ directory has a verovio.dll as well as a number of other files.

## Installing Verovio Into Our System

By running the final command above (the "install" command), it will take all the vital stuff you need (the .dll, resource files, headers) and put them all under your C:/Program Files (x86)/ directory, under the folder /Verovio/.  Now, while you have built a 64-bit dll, it will still install into the (x86) Program Files, don't worry about that.  32-bit is the default for their project (which is one reason why we had to use the special terminal: so it builds in 64-bit mode), and they haven't gotten around to moving it into the right Program Files yet for the times where you are building in 64-bit mode.

So you've done it!  From here, you can delete the entire repository that you have cloned; you don't need it any more.  The program in this repository should work just fine for you now.
