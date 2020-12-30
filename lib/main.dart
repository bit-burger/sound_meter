import 'dart:async';

import 'package:flutter/services.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic/flutter_neumorphic.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_neumorphic_sliders.dart';
import 'package:flutter_sound/flutter_sound.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Settings.preferences = await SharedPreferences.getInstance();
  if (!Settings.preferences.containsKey("lowValue")) {
    Settings.preferences.setDouble("lowValue", 0);
    Settings.preferences.setDouble("highValue", 100);
    Settings.preferences.setDouble("maxValue", 80);
  } else {
    print(Settings.preferences.getDouble("lowValue"));
    print(Settings.preferences.getDouble("highValue"));
    print(Settings.preferences.getDouble("maxValue"));
  }
  runApp(App());
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
    return NeumorphicApp(
      home: MyApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isRecording = false;
  NoiseMeter _noiseMeter;
  StreamSubscription<NoiseReading> _noiseSubscription;

  @override
  void initState() {
    super.initState();
    _noiseMeter = NoiseMeter(onError);
    startRecording();
  }

  void startRecording() {
    try {
      _noiseSubscription = _noiseMeter.noiseStream.listen(onData);
    } catch (exception) {
      print(exception);
    }
    this._isRecording = true;
  }

  void stopRecording() async {
    try {
      if (_noiseSubscription != null) {
        _noiseSubscription.cancel();
        _noiseSubscription = null;
      }
      this.setState(() {
        this._isRecording = false;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  void onData(NoiseReading data) {
    setState(() {
      this.data = data.meanDecibel;
    });
  }

  double data;

  void onError(PlatformException error) {
    print("**********************");
    print(error.toString());
    print("**********************");
    _isRecording = false;
  }

  void _openFileExplorer() async {
    FilePicker.platform.pickFiles();
  }

  Widget colorBox(int color, bool isActivated) => Expanded(
        child: NeumorphicButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            _openFileExplorer();
          },
          margin: EdgeInsets.symmetric(vertical: 7.5, horizontal: 15),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 250),
            color: isActivated ? Color(color) : NeumorphicColors.background,
          ),
          style: NeumorphicStyle(),
        ),
      );

  List<Widget> getContent(double db) {
    final _db = ((db / 1.2) - Settings.preferences.getDouble("lowValue")) /
        (Settings.preferences.getDouble("highValue") -
            Settings.preferences.getDouble("lowValue")) *
        10;
    print(db.toString() + " -> " + _db.toString());
    final List<Widget> list = List<Widget>.generate(
        10, (i) => colorBox(colorCodes[i], _db > (9 - i).toDouble()));
    list.insert(
        0,
        SizedBox(
          height: 5,
        ));
    list.add(SizedBox(
      height: 5,
    ));
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
          onVerticalDragStart: (details) {
            y = details.globalPosition.dy;
          },
          onVerticalDragUpdate: (details) {
            if ((details.globalPosition.dy - y) > 200) {
              stopRecording();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) {
                  return Settings(startRecording);
                }),
              );
            }
          },
          child: Container(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7.5),
              child: Column(
                children: getContent(data ?? 0),
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
  final void Function() continueRecording;
  Settings(this.continueRecording);
  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  double lowValue = 0;
  double highValue = 0;
  double maxValue = 0;

  void checkMaxValue() {
    if (maxValue > highValue) {
      maxValue = highValue;
    } else if (maxValue < lowValue) {
      maxValue = lowValue;
    }
  }

  @override
  void dispose() {
    Settings.preferences.setDouble("lowValue", lowValue);
    Settings.preferences.setDouble("highValue", highValue);
    Settings.preferences.setDouble("maxValue", maxValue);
    widget.continueRecording();
    super.dispose();
  }

  @override
  void initState() {
    setState(() {
      lowValue = Settings.preferences.getDouble("lowValue");
      highValue = Settings.preferences.getDouble("highValue");
      maxValue = Settings.preferences.getDouble("maxValue");
    });
    super.initState();
  }

  static final double valueUnterschied = 20;
  static final textColor = Colors.grey[700];
  static final TextStyle titleStyle = TextStyle(
    color: SettingsState.textColor,
    fontSize: 17,
  );
  static const EdgeInsets titleInsets =
      EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeumorphicTheme.currentTheme(context).baseColor,
      appBar: CustomNeumorphicAppBar(
        title: Text("Settings"),
        buttonStyle: NeumorphicStyle(boxShape: NeumorphicBoxShape.circle()),
      ),
      body: Container(
        padding: EdgeInsets.all(25).copyWith(top: 0),
        child: Neumorphic(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Padding(
                padding: titleInsets,
                child: Text(
                  "Decibel range",
                  style: titleStyle,
                ),
              ),
              CustomNeumorphicRangeSlider(
                valueLow: lowValue,
                valueHigh: highValue,
                max: 100,
                min: 0,
                onChangedLow: (value) {
                  setState(() {
                    if (value <= highValue - valueUnterschied) {
                      lowValue = value;
                    } else {
                      lowValue = highValue - valueUnterschied;
                    }
                    checkMaxValue();
                  });
                },
                onChangeHigh: (value) {
                  setState(() {
                    if (value >= lowValue + valueUnterschied) {
                      highValue = value;
                    } else {
                      highValue = lowValue + valueUnterschied;
                    }
                    checkMaxValue();
                  });
                },
              ),
              Padding(
                padding: titleInsets,
                child: Text(
                  "When to play the sound",
                  style: titleStyle,
                ),
              ),
              CustomNeumorphicSlider(
                value: maxValue,
                max: 100,
                min: 0,
                maxValue: highValue,
                minValue: lowValue,
                onChanged: (value) {
                  setState(() {
                    maxValue = value;
                    checkMaxValue();
                  });
                },
              ),
              Padding(
                padding: titleInsets,
                child: Text(
                  "Custom sound",
                  style: titleStyle,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(5),
                child: Container(
                  height: 50,
                  width: double.infinity,
                  child: Neumorphic(
                    style: NeumorphicStyle(
                        boxShape: NeumorphicBoxShape.roundRect(
                            BorderRadius.circular(25)),
                        depth: -NeumorphicTheme.currentTheme(context).depth),
                    child: Row(
                      children: [
                       NeumorphicIconButton(Icons.play_arrow,secondIcon: Icons.pause,iconSize: 45,onPressed: ([bool bool]){},)
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
