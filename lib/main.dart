import 'package:flutter/services.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.preferences = await SharedPreferences.getInstance();
  runApp(App());
  if(!Settings.preferences.containsKey("lowValue")) {
    Settings.preferences.setDouble("lowValue", 0);
    Settings.preferences.setDouble("highValue", 100);
    Settings.preferences.setDouble("maxValue", 80);
  } else {
    print(Settings.preferences.getDouble("lowValue"));
    print(Settings.preferences.getDouble("highValue"));
    print(Settings.preferences.getDouble("maxValue"));

  }
}

const List<int> colorCodes = [
  0xFFFFADAD,
  0xFFFFC2A9,
  0xFFFFD6A5,
  0xFFFDFFB6,
  0xFFCAFFBF,
  0xFFB3FBDF,
  0xFFAAE0EF,
  0xFFA0C4FF,
  0xFFBDB2FF,
  0xFFEFADFF,
];

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MyApp());
  }
}


class MyApp extends StatefulWidget {

  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {



  bool _isRecording = false;
  NoiseMeter _noiseMeter;

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter(onError);
    _isRecording = true;
  }

  void onError(PlatformException error) {
    print("**********************");
    print(error.toString());
    print("**********************");
    _isRecording = false;
  }

  void _openFileExplorer() async {
    FilePicker.platform.pickFiles();

  }

  void stop() async {
    setState(() {
      this._isRecording = false;
    });
  }

  Widget colorBox(int color,bool isActivated) => Expanded(
    child: NeumorphicButton(
      padding: EdgeInsets.zero,
      onPressed: (){
        _openFileExplorer();
      },
      margin: EdgeInsets.symmetric(vertical: 7.5,horizontal: 15),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        color: isActivated ? Color(color) : NeumorphicColors.background,
      ),
      style: NeumorphicStyle(
      ),
    ),
  );

  List<Widget> getContent(double db) {
    final _db = (db - Settings.preferences.getDouble("lowValue"))/(Settings.preferences.getDouble("highValue")-Settings.preferences.getDouble("lowValue"))*10;
    print(db.toString() +" -> " + _db.toString());
    final List<Widget> list = List<Widget>.generate(10, (i) => colorBox(colorCodes[i],_db>(9-i).toDouble()));
    list.insert(0, SizedBox(height: 5,));
    list.add(SizedBox(height: 5,));
    return list;
  }

  double y;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeumorphicColors.background,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (details){
            y = details.globalPosition.dy;
          },
          onVerticalDragUpdate: (details){
            print(details.globalPosition.dy-y);
            if((details.globalPosition.dy-y)>200) {
              showDialog(
                  context: context,
                  builder: (context){
                    return Settings();
                  }
              );
            }
          },
          child: Container(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7.5),
              child: StreamBuilder<NoiseReading>(
                stream: _isRecording ? _noiseMeter.noiseStream : null,
                initialData: NoiseReading(<double>[0]),
                builder: (context,snapshot){
                  return Column(
                    children: getContent(snapshot?.data?.meanDecibel ?? 0),
                  );
                }
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Settings extends StatefulWidget {
  static SharedPreferences preferences;
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  double lowValue = 0;
  double highValue = 0;
  double maxValue = 0;

  @override
  void dispose() {
    Settings.preferences.setDouble("lowValue", lowValue);
    Settings.preferences.setDouble("highValue", highValue);
    super.dispose();
  }
  @override
  void initState() {
    setState(() {
      lowValue = Settings.preferences.getDouble("lowValue");
      highValue = Settings.preferences.getDouble("highValue");
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 50),
        height: MediaQuery.of(context).size.height*0.5,
        child: Neumorphic(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                "Decibel range"
              ),
              NeumorphicRangeSlider(
                valueLow: lowValue,
                valueHigh: highValue,
                max: 100,
                min: 0,
                onChangedLow: (value){
                  setState(() {
                    lowValue = value;
                  });
                },
                onChangeHigh: (value){
                  setState(() {
                    highValue = value;
                  });
                },
              ),
              Text(
                "When to play the sound"
              ),
              NeumorphicSlider(
                value: maxValue,
                onChanged: (value){
                  setState(() {
                    maxValue = value;
                  });
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

