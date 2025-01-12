import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services ;       //rootBundle.loadString
import 'package:csv/csv.dart' as csv;
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;
// import 'package:flutter/foundation.dart' as foundation;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:cp949_codec/cp949_codec.dart' as cp949;
import 'dart:math' as math;

class Win {
  late int turn;
  late int date;
  late String day;
  late int win1;
  late int win2;
  late int win3;
  late int win4;
  late int win5;
  late int win6;
  late int win7;

  Win(this.turn, this.date, this.win1, this.win2, this.win3, this.win4, this.win5, this.win6, this.win7){
    day = DateTime.fromMillisecondsSinceEpoch(date).toString();
  }

  Win.formJson({required this.turn, required this.date, required this.win1, required this.win2, required this.win3,  required this.win4,
    required this.win5, required this.win6, required this.win7}){
    day = DateTime.fromMillisecondsSinceEpoch(date).toString();
  }
  Win.formMap(Map<String, Object?> item){
    day = DateTime.fromMillisecondsSinceEpoch(item['date'] as int).toString();
    turn = item['turn'] as int;
    date = item['date'] as int;
    win1 = item['win1'] as int;
    win2 = item['win2'] as int;
    win3 = item['win3'] as int;
    win4 = item['win4'] as int;
    win5 = item['win5'] as int;
    win6 = item['win6'] as int;
    win7 = item['win7'] as int;
  }

  
  Map<String, dynamic> toMap(){
    return {
      'turn' : turn,
      'date': date,
      'win1': win1,
      'win2': win2,
      'win3': win3,
      'win4': win4,
      'win5': win5,
      'win6': win6,
      'win7': win7
    };
  }
}

class Lotto{
  late final List<List<int>> wins;
  // late final io.File csvFile;
  // Lotto._(List<List<int>> list, io.File file){
  //   wins = list;
  //   csvFile = file;
  // }
  Lotto._(List<List<int>> list){
    wins = list;
  }

  static Future<Lotto> create() async {
    var directory = await path_provider.getApplicationDocumentsDirectory();   // 웹에서는 동작 하지 않음.  우선 웹은 상관하지 말자!!
    // import 'dart:html' as html;                                            // 웹에서 동작하게 하려면 브라우저 저장소를 이용해야한다. 
    // // 데이터 저장
    // html.window.localStorage['key'] = 'value';
    // // 데이터 읽기
    // String? value = html.window.localStorage['key'];
    // // 데이터 삭제
    // html.window.localStorage.remove('key');
    // // 전체 삭제
    // html.window.localStorage.clear();


    List<List<int>> list = [<int>[]];
    print('directory : ${directory.path}');
    var file = io.File(path.join(directory.path, '.lotto.csv'));

    if (await file.exists()){// 있으면 로딩
      print('file.exists() file.path : ${file.path}');
      String csvString = await file.readAsString();
      List<List<dynamic>> listDynamic = const csv.CsvToListConverter().convert<dynamic>(csvString);
      list = listDynamic.map((row) {
        return row.map((item) {
          // 강제 변환하기 전에 타입 체크
          if (item is int) {
            return item; // 이미 int인 경우
          } else if (item is String) {
            // 문자열인 경우 정수로 변환, 실패 시 0
            return int.tryParse(item) ?? 0;
          }
          // 기타 타입은 기본값으로 0 처리
          return 0;
        }).toList();
      }).toList();
    }else{// 없으면 파일 생성
      print('file.exists() 없음 생성');
      file = await file.create();
      list = await getListFromCSV();   // assets 에서 가져옴
      String csvString = const csv.ListToCsvConverter().convert(list); 
      await file.writeAsString(csvString, flush: true); // 파일 저장
    }
    
    print('file.path : ${file.path}');

    // 데이터 업데이트 
    list = await _updateWins(list, file); // 갱신데이터가 있는지 검사

    return Lotto._(list);
  } 

  static Future<List<List<int>>> getListFromCSV() async {
    var csvData = await services.rootBundle.loadString('assets/lotto.csv');

    List<List<int>> rows = List<List<int>>.generate(csvData.split('\r\n').length, (index) => []);
    for (var line in csvData.split('\r\n')){
      int index = int.parse(line.split(',')[0]);
      for (var item in line.split(',')){
        rows[index - 1].add(int.parse(item));
      }
    }
    return rows;
  }

  static Future<List<List<int>>> _updateWins(List<List<int>> wins, io.File file) async {
    var list = wins;
    int today = DateTime.now().millisecondsSinceEpoch;
    int lately = list.last[1];
    final int nextTime = const Duration(days: 7, hours:21).inMilliseconds;
    if (today - lately < nextTime) return list;

    while (today - lately > nextTime) {
      var item = await getFromHomepageWins(list.length + 1);
      list.add(item);
      lately = item[1];
    }
    String csvString = const csv.ListToCsvConverter().convert(list);
    await file.writeAsString(csvString, flush: true); // 

    return list;
  }

  /// 모바일 페이지에서 크롤링 하기
  static Future<List<int>> _getWinsForAndroid(int turnNum) async {
    // turnNum = 1144;
    var address = 'm.dhlottery.co.kr';
    var url = Uri.https(address, 'gameResult.do',{'method': 'byWin'});
    var response = await http.post(
        url,
        body: {'drwNo': '$turnNum', 'hdrwComb': '1', 'dwrNoList' : '$turnNum'}
    );
    debugPrint('response.statusCode : ${response.statusCode}');
    // debugPrint('${response.body}');
    var regex = RegExp(r'\d+');
    var document = html.parse(cp949.cp949.decode(response.bodyBytes));
    // debugPrint(document.outerHtml);
    // var date = document.querySelector('#dwrNoList :first-child')?.text.trim();
    var date = document.querySelector('#dwrNoList [selected]')?.text.trim();
    debugPrint(date.toString());

    var date1 = date?.split(' ').map((e) =>  regex.allMatches(e).map((m) => m.group(0))).toList();
    debugPrint(date1.toString());
    var date2 = date1?.toList();
    debugPrint(date2?[0].toString());

    debugPrint(date2?[0].toList()[0].toString());
    debugPrint(date2?[0].toList()[1].toString());
    debugPrint(date2?[1].toList()[0].toString());
    debugPrint(date2?[2].toList()[0].toString());

    int turn = int.parse(date2?[0].toList()[0] ?? '');
    int year = int.parse(date2?[0].toList()[1] ?? '');
    int month = int.parse(date2?[1].toList()[0] ?? '');
    int  day= int.parse(date2?[2].toList()[0] ?? '');

    List<int> win = document.querySelectorAll('span.ball').map((element)=> int.parse(element.text)).toList();

    return <int>[turn, DateTime(year, month, day).millisecondsSinceEpoch] + win;
  }

  static Future<List<int>> getFromHomepageWins(int turnNum) async {
    if (io.Platform.isAndroid){
      return _getWinsForAndroid(turnNum);
    }
    var address = 'dhlottery.co.kr';
    debugPrint('io.Platform.operatingSystem : ${io.Platform.operatingSystem.toString()}');

    var url = Uri.https(address, 'gameResult.do',{'method': 'byWin'});
    var response = await http.post(
      url, 
      body: {'drwNo': '$turnNum', 'hdrwComb': '1', 'dwrNoList' : '$turnNum'}
      );
    debugPrint('response.statusCode : ${response.statusCode}');
    // debugPrint('${response.body}');
    var regex = RegExp(r'\d+');
    var document = html.parse(cp949.cp949.decode(response.bodyBytes));
    // debugPrint(document.outerHtml);
    var date = document.querySelector('p.desc')?.text;
    debugPrint(date.toString());
    var date1 = date?.split(' ').map((e) =>  regex.allMatches(e).map((m) => m.group(0))).toList();
    debugPrint(date1.toString());
    int year = int.parse(date1?[0].toList().join() ?? '');
    int month = int.parse(date1?[1].toList().join() ?? '');
    int  day= int.parse(date1?[2].toList().join() ?? '');
    
    String turn = regex.allMatches(document.querySelector('h4')?.text ?? '').map((e) => e.group(0)).toList().join();
    
    List<int> win = document.querySelectorAll('span.ball_645').map((element)=> int.parse(element.text)).toList();
    
    return <int>[int.parse(turn), DateTime(year, month, day).millisecondsSinceEpoch] + win;
  } // end getFromHomepageWins

  static List<int> drawWin(List<List<int>> list){
    int weight = 5;
    List<int> weights = List.generate(45, (_) => 1, growable: false);
    for(var i = list.length - 1; i >= list.length - weight; i--){
      for(var j = 2; j < 8; j++){
        weights[list[i][j] - 1]++  ;
        weights[list[i][j] - 1]++  ;
      }
    }
    List<int> weightList = [];
    for (var i = 1; i < 46; i++){
      for (var j = weights[i - 1]; j > 0; j--){
        weightList.add(i);
      }
    }

    Set<int> win = {};
    while(win.length < 6){
      int num = math.Random().nextInt(weightList.length);
      int selectNum = weightList[num];
      win.add(selectNum);
      do{
        weightList.remove(selectNum);
      }while(weightList.contains(selectNum));
    }
    List<int> wins  = win.toList();
    wins.sort();
    return wins;
  }

  List<int> createWin(int weight){
    // int count = 0;
    List<int> weights = List.generate(45, (_) => 1, growable: false);
    for(var i = wins.length - 1; i >= wins.length - weight; i--){
      // print('${count++} ${wins[i]}');
      for(var j = 2; j < 8; j++){
        // if (i == 1140){
        //   print(wins[i][j]);  
        // }
        weights[wins[i][j] - 1]++  ;//= weights[wins[i][j] ] + 1;
      }
    }
    // print(weights);
    List<int> weightList = [];
    for (var i = 1; i < 46; i++){
      // print(i);
      for (var j = weights[i - 1]; j > 0; j--){
        // if(i == 1) print(j);
        weightList.add(i);
      }
    }
    // print(weightList);

    Set<int> win = {};
    while(win.length < 6){
      // win.add(math.Random().nextInt(45) + 1);
      int num = math.Random().nextInt(weightList.length);
      int selectNum = weightList[num];
      // print('$num $selectNum');
      win.add(selectNum);
      do{
        weightList.remove(selectNum);
      }while(weightList.contains(selectNum));
      // print(weightList);
    }
    List<int> list  = win.toList();
    list.sort();
    
    

    return list;
  }

 
}