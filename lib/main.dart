/// Author: Matthew Williams
/// Date:   March 2024

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jovial_svg/jovial_svg.dart';

import 'myIO.dart';
import 'verovio/verovio_api.dart';

void makeVerovioEngraving() {
  VerovioAPI verovio = VerovioAPI();
  String meiContent = IOWorker.getFileText("oneLine.mei");
  // print(verovio.getOptions());
  verovio.setOptions("""{
    'scale': 130,
    'footer': 'none'
  }""");
  verovio.loadData(meiContent);
  String svgContent = verovio.getSVGOutput(generateXml: true);
  File file = File("assets/svgOutput.svg");
  file.writeAsString(svgContent);
  // Done writing file!
}

void main() {
  //makeVerovioEngraving();
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  MainApp({super.key});
  
  Function getSvgContent = () {
    VerovioAPI verovio = VerovioAPI();
    String meiContent = IOWorker.getFileText("oneLine.mei");
    verovio.loadData(meiContent);
    return verovio.getSVGOutput();
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ScalableImageWidget(si: ScalableImage.fromSvgString(getSvgContent()))
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
