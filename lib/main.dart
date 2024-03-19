/// Author: Matthew Williams
/// Date:   March 2024

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:verovio_integration/test/verovio_tests.dart';

import 'myIO.dart';
import 'verovio/verovio_api.dart';

void makeVerovioEngraving() {
  VerovioAPI verovio = VerovioAPI();
  String meiContent = IOWorker.getFileText("Joplin_Maple_leaf_Rag.mei");
  // print(verovio.getOptions());
  verovio.setOptions("""{
    'footer': 'none'
  }""");
  verovio.loadData(meiContent);
  String svgContent = verovio.getSVGOutput(generateXml: true);
  File file = File("assets/svgOutput.svg");
  file.writeAsString(svgContent);
  // Done writing file!
}

void main() {
  makeVerovioEngraving();
  //doLibTests(50, 50);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ScalableImageWidget(si: ScalableImage.fromSvgString(IOWorker.getFileText("svgOutput.svg")))
          /*child: ScalableImageWidget.fromSISource (
            //si: ScalableImageSource.fromSvg(rootBundle, "assets/svgOutput.svg"),
            si: ScalableImage.fromSvgString(""),
            scale: 20,
            fit: BoxFit.fitHeight,
          )*/
        ),
      ),
    );
  }
}
