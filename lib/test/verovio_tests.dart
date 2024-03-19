
// ignore_for_file: avoid_print

import 'dart:io';

import '../myIO.dart';
import '../verovio/verovio_api.dart';


bool addRemoveSwitch = true;
int c = 0;

void doPrintTimesList(List<int> times, String title, int reps, int sets) {
  int sum = times.fold(0, (previousValue, element) => previousValue += element);
  double avg = sum / sets;
  double perItemAvg = avg / reps;
  
  print("");
  print("-----------------------------------------");
  print("Testing results from a ${reps}x$sets");
  print("-----------------------------------------");
  print(title);
  print("-----------------------------------------");
  print(times);
  print("Total test run time:\t\t$sum");
  print("Average set time:\t\t$avg");
  print("Average individual time:\t$perItemAvg");
  print("-----------------------------------------");
  print("");
}

void performTest(Function testFunc, int reps, int sets, VerovioAPI verovio, String content, String title) {
  List<int> timesList = [];
  for (int i = 0; i < sets; i++) {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    for (int j = 0; j < reps; j++) {
      testFunc(verovio, content);
    }
    timesList.add(DateTime.now().millisecondsSinceEpoch - startTime);
  }
  doPrintTimesList(timesList, title, reps, sets);
}

void doLibTests(int reps, int sets) {
  VerovioAPI verovio = VerovioAPI();
  String content = IOWorker.getFileText("oneLine.mei");
  verovio.loadData(content);
  
  // print(verovio.getOptions());
  
  performTest(
    testLoadAndRenderFull,
    reps, sets, verovio, content,
    "Base Load And Render Test"
  );
  
  // Load the data in so that there's something to render
  verovio.loadData(content);
  performTest(
    testRenderOnly,
    reps, sets, verovio, "",
    "Render Only Test"
  );
  
  performTest(
    testLoadEditAndRender,
    reps, sets, verovio, content,
    "Load, Edit, and Render Test"
  );
  
  // Load the data in so that there's something to edit/render
  verovio.loadData(content);
  performTest(
    testEditAndRenderOnly,
    reps, sets, verovio, "",
    "Edit and Render Only Test"
  );
  
  // Load the data in so that there's something to edit/render
  /*verovio.loadData(content);
  performTest(
    testEditPlaceAndRender,
    reps, sets, verovio, "",
    "Edit, Place, and Render Test"
  );*/
}

void testLoadAndRenderFull(VerovioAPI verovio, String content) {
  verovio.loadData(content);
  verovio.getSVGOutput();
}

void testRenderOnly(VerovioAPI verovio, String _) {
  verovio.getSVGOutput();
}

void testLoadEditAndRender(VerovioAPI verovio, String content) {
  verovio.loadData(content);
  verovio.executeEdit("{'action': 'delete', 'param': {'elementId': 'd1e190'}}");
  verovio.getSVGOutput();
}

void testEditAndRenderOnly(VerovioAPI verovio, String _) {
  if (addRemoveSwitch) {
    verovio.executeEdit("{'action': 'delete', 'param': {'elementId': '[chained-id]'}}");
  } else {
    verovio.executeEdit("{'action': 'insert', 'param': {'elementType': 'note', 'startid': 'd34e1'}}");
  }
  verovio.getSVGOutput();
  addRemoveSwitch = !addRemoveSwitch;
}

/// This method doesn't work right now
void testEditPlaceAndRender(VerovioAPI verovio, String _) {
  if (addRemoveSwitch) {
    verovio.executeEdit("{'action': 'delete', 'param': {'elementId': '[chained-id]'}}");
  } else {
    verovio.executeEdit("{'action': 'insert', 'param': {'elementType': 'note', 'startid': 'd34e1'}}");
    verovio.executeEdit("{'action': 'set', 'param': {'elementId': '[chained-id]', 'attribute': 'oct', 'value': '3'}}");
    //verovio.redoPitchPosLayout();
    //verovio.redoLayout();
  }
  String svg = verovio.getSVGOutput();
  File file = File("C:/Users/mbwil/Desktop/output/testing/secondaryOutput$c.svg");
  c++;
  file.writeAsString(svg);
  addRemoveSwitch = !addRemoveSwitch;
}

void experimentLibFuncs() {
  VerovioAPI verovio = VerovioAPI();
  String content = IOWorker.getFileText("fullPage.mei");
  verovio.loadData(content);
  verovio.executeEdit("{'action': 'delete', 'param': {'elementId': 'd1e966'}}");
  verovio.executeEdit("{'action': 'commit'}");
  print("Page in score: ${verovio.getPageCount()}");
  String svgContent = verovio.getSVGOutput();
  File file = File("C:/Users/mbwil/Desktop/alteredOutput2.svg");
  print("-----------------GOT FILE BUILT");
  file.writeAsString(svgContent);
}