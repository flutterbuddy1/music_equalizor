import 'dart:async';
import 'package:equalizer/equalizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:nowplaying/nowplaying.dart';
import 'package:provider/provider.dart';

void main() {
  NowPlaying.instance.start(resolveImages: true);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool enableCustomEQ = false;

  @override
  void initState() {
    super.initState();
    Equalizer.init(0);
    initlization();
  }

  initlization() async {
    final bool hasShownPermissions =
        await NowPlaying.instance.requestPermissions();

    if (!hasShownPermissions) {
      NowPlaying.instance.requestPermissions();
    } else {
      NowPlaying.instance.start();
    }
  }

  @override
  void dispose() {
    Equalizer.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamProvider.value(
      value: NowPlaying.instance.stream,
      initialData: NowPlaying.instance.track,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Equalizer Test App'),
          ),
          body: Consumer<NowPlayingTrack>(
            builder: (context, track, _) => ListView(
              children: [
                Container(
                  margin: EdgeInsets.all(10),
                  child: track.title != null
                      ? Column(
                          children: [
                            Text("Now Playing"),
                            SizedBox(
                              height: 10,
                            ),
                            Text(
                              track.title.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            )
                          ],
                        )
                      : Text(
                          "Music Not Playing",
                          textAlign: TextAlign.center,
                        ),
                ),
                SizedBox(height: 10.0),
                Center(
                  child: Builder(
                    builder: (context) {
                      return FlatButton.icon(
                        icon: Icon(Icons.equalizer),
                        label: Text("Device Equalizor"),
                        color: Colors.blue,
                        textColor: Colors.white,
                        onPressed: () async {
                          try {
                            await Equalizer.open(0);
                          } on PlatformException catch (e) {
                            final snackBar = SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('${e.message}\n${e.details}'),
                            );
                            Scaffold.of(context).showSnackBar(snackBar);
                          }
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: 10.0),
                Container(
                  color: Colors.grey.withOpacity(0.1),
                  child: SwitchListTile(
                    title: Text('Custom Equalizer'),
                    value: enableCustomEQ,
                    onChanged: (value) {
                      Equalizer.setEnabled(value);
                      setState(() {
                        enableCustomEQ = value;
                      });
                    },
                  ),
                ),
                FutureBuilder<List<int>>(
                  future: Equalizer.getBandLevelRange(),
                  builder: (context, snapshot) {
                    return snapshot.connectionState == ConnectionState.done
                        ? CustomEQ(enableCustomEQ, snapshot.data!)
                        : CircularProgressIndicator();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomEQ extends StatefulWidget {
  const CustomEQ(this.enabled, this.bandLevelRange);

  final bool enabled;
  final List<int> bandLevelRange;

  @override
  _CustomEQState createState() => _CustomEQState();
}

class _CustomEQState extends State<CustomEQ> {
  double? min, max;
  String? _selectedValue;
  Future<List<String>>? fetchPresets;

  @override
  void initState() {
    super.initState();
    min = widget.bandLevelRange[0].toDouble();
    max = widget.bandLevelRange[1].toDouble();
    fetchPresets = Equalizer.getPresetNames();
  }

  @override
  Widget build(BuildContext context) {
    int bandId = 0;

    return FutureBuilder<List<int>>(
      future: Equalizer.getCenterBandFreqs(),
      builder: (context, snapshot) {
        return snapshot.connectionState == ConnectionState.done
            ? Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: snapshot.data!
                        .map((freq) => _buildSliderBand(freq, bandId++))
                        .toList(),
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildPresets(),
                  ),
                ],
              )
            : CircularProgressIndicator();
      },
    );
  }

  Widget _buildSliderBand(int freq, int bandId) {
    return Column(
      children: [
        SizedBox(
          height: 250.0,
          child: FutureBuilder<int>(
            future: Equalizer.getBandLevel(bandId),
            builder: (context, snapshot) {
              return FlutterSlider(
                disabled: !widget.enabled,
                axis: Axis.vertical,
                rtl: true,
                min: min,
                max: max,
                values: [snapshot.hasData ? snapshot.data!.toDouble() : 0],
                onDragCompleted: (handlerIndex, lowerValue, upperValue) {
                  Equalizer.setBandLevel(bandId, lowerValue.toInt());
                },
              );
            },
          ),
        ),
        Text('${freq ~/ 1000} Hz'),
      ],
    );
  }

  Widget _buildPresets() {
    return FutureBuilder<List<String>>(
      future: fetchPresets,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final presets = snapshot.data;
          if (presets!.isEmpty) return Text('No presets available!');
          return DropdownButtonFormField(
            decoration: InputDecoration(
              labelText: 'Available Presets',
              border: OutlineInputBorder(),
            ),
            value: _selectedValue,
            onChanged: widget.enabled
                ? (value) {
                    Equalizer.setPreset(value.toString());
                    setState(() {
                      _selectedValue = value.toString();
                    });
                  }
                : null,
            items: presets.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          );
        } else if (snapshot.hasError)
          return Text(snapshot.error.toString());
        else
          return CircularProgressIndicator();
      },
    );
  }
}
