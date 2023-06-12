import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl_PL', null);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  @override
  _WeatherHomePageState createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  Map<String, dynamic>? _weatherData;
  String? _cityName;

  @override
  void initState() {
    super.initState();
    _getSavedCityName().then((savedCityName) {
      if (savedCityName != null) {
        _fetchWeatherData(savedCityName);
      } else {
        _fetchWeatherData('Częstochowa');
      }
    });
  }

  Future<void> _fetchWeatherData(String cityName) async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://api.weatherapi.com/v1/forecast.json?key=bad6992f8a184659840180617222012&q=$cityName&days=3&aqi=no&alerts=no'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> weatherData = jsonDecode(response.body);

        // Tłumaczenie opisu pogody dla bieżącej prognozy
        final currentWeatherDescription =
            weatherData['current']['condition']['text'];
        weatherData['current']['condition']['text'] =
            await translateToPolish(currentWeatherDescription);

        // Tłumaczenie opisu pogody dla prognoz na kolejne dni
        for (int i = 0; i < 2; i++) {
          final dayWeatherDescription = weatherData['forecast']['forecastday']
              [i + 1]['day']['condition']['text'];
          weatherData['forecast']['forecastday'][i + 1]['day']['condition']
              ['text'] = await translateToPolish(dayWeatherDescription);
        }

        setState(() {
          _weatherData = weatherData;
          _cityName = cityName;
        });
      } else {
        throw Exception('Failed to fetch weather data');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _saveCityName(String cityName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cityName', cityName);
  }

  Future<String?> _getSavedCityName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('cityName');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_cityName ?? 'Weather App'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              final selectedCity = await showSearch<String>(
                context: context,
                delegate: CitySearchDelegate(searchCity: searchCity),
              );
              if (selectedCity != null) {
                _saveCityName(selectedCity);
                _fetchWeatherData(selectedCity);
              }
            },
          ),
        ],
      ),
      body: _weatherData == null
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Today's weather
                Container(
                  child: Column(
                    children: [
                      // Today's date with "Dzisiaj"
                      FutureBuilder<String>(
                        future: translateToPolish(
                            DateFormat('EEEE', 'en_US').format(DateTime.now())),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          } else if (snapshot.hasError || !snapshot.hasData) {
                            return Text('Error: ${snapshot.error}');
                          } else {
                            final translatedDayOfWeek = snapshot.data!;
                            final formattedDate = DateFormat('d MMMM', 'pl_PL')
                                .format(DateTime.now());
                            final fullFormattedDate =
                                '$translatedDayOfWeek, $formattedDate - Dzisiaj';

                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                fullFormattedDate,
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                        },
                      ),
                      // Weather icon
                      Image.network(
                        'https:${_weatherData!['current']['condition']['icon']}',
                      ),
                      // Temperature
                      Text(
                        '${_weatherData!['current']['temp_c']}°C',
                        style: TextStyle(fontSize: 48),
                      ),
                      // Weather description
                      Text(
                        _weatherData!['current']['condition']['text'],
                        style: TextStyle(fontSize: 24),
                      ),
                      // Wind speed
                      Text(
                        'Wiatr: ${_weatherData!['current']['wind_kph']} km/h',
                        style: TextStyle(fontSize: 18),
                      ),
                      // Humidity
                      Text(
                        'Wilgotność: ${_weatherData!['current']['humidity']}%',
                        style: TextStyle(fontSize: 18),
                      ),
                      // Precipitation
                      GestureDetector(
                        onTap: () {
                          final maxPrecip = _weatherData!['forecast']
                                  ['forecastday'][0]['hour']
                              .reduce((curr, next) =>
                                  curr['precip_mm'] > next['precip_mm']
                                      ? curr
                                      : next);
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Wykres opadów'),
                                content: Container(
                                  height: 300,
                                  child: AspectRatio(
                                    aspectRatio: 1.5,
                                    child: SfCartesianChart(
                                      backgroundColor: Colors.grey[100],
                                      plotAreaBorderColor: Colors.transparent,
                                      zoomPanBehavior: ZoomPanBehavior(
                                        enablePinching: true,
                                        enablePanning: true,
                                        enableMouseWheelZooming: true,
                                      ),
                                      primaryXAxis: CategoryAxis(
                                        majorGridLines:
                                            MajorGridLines(width: 0),
                                        axisLine: AxisLine(width: 0),
                                        labelStyle: TextStyle(
                                            color: Colors.blueGrey,
                                            fontSize: 12),
                                        labelRotation: -45,
                                      ),
                                      primaryYAxis: NumericAxis(
                                        minimum: 0,
                                        axisLine: AxisLine(width: 0),
                                        majorTickLines: MajorTickLines(size: 0),
                                        majorGridLines:
                                            MajorGridLines(color: Colors.grey),
                                        title: AxisTitle(
                                            text: 'Opady (mm)',
                                            textStyle: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey)),
                                        labelStyle: TextStyle(
                                            color: Colors.blueGrey,
                                            fontSize: 12),
                                      ),
                                      series: <ChartSeries>[
                                        LineSeries<dynamic, String>(
                                          dataSource: _weatherData!['forecast']
                                              ['forecastday'][0]['hour'],
                                          xValueMapper: (hourData, _) =>
                                              hourData['time']
                                                  .substring(11, 16),
                                          yValueMapper: (hourData, _) =>
                                              hourData['precip_mm'],
                                          name: 'Opady',
                                          color: Colors.deepPurple,
                                          width: 2,
                                          markerSettings:
                                              MarkerSettings(isVisible: false),
                                          dataLabelSettings: DataLabelSettings(
                                              isVisible: false),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  Text(
                                    'Największe opady: ${maxPrecip['precip_mm']} mm o godzinie ${maxPrecip['time'].substring(11, 16)}',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Zamknij'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Precipitation
                            Text(
                              'Opady: ${_weatherData!['current']['precip_mm']} mm',
                              style: TextStyle(fontSize: 18),
                            ),
                            SizedBox(width: 4),
                            // Raindrop icon
                            Icon(Icons.water_drop_sharp, size: 24),
                          ],
                        ),
                      ),

                      // Pressure
                      Text(
                        'Ciśnienie: ${_weatherData!['current']['pressure_mb']} hPa',
                        style: TextStyle(fontSize: 18),
                      ),
                      // Visibility
                      Text(
                        'Widoczność: ${_weatherData!['current']['vis_km']} km',
                        style: TextStyle(fontSize: 18),
                      ),
                      // Cloud cover
                      Text(
                        'Zachmurzenie: ${_weatherData!['current']['cloud']}%',
                        style: TextStyle(fontSize: 18),
                      ),
                      // Feels like
                      Text(
                        'Odczuwalna temperatura: ${_weatherData!['current']['feelslike_c']}°C',
                        style: TextStyle(fontSize: 18),
                      ),
                      // UV index
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Wykres indeksu UV'),
                                content: _buildUvIndexChart(_weatherData!),
                                actions: [
                                  TextButton(
                                    child: Text('Zamknij'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Indeks UV: ',
                              style: TextStyle(fontSize: 18),
                            ),
                            Icon(
                              Icons.wb_sunny,
                              size: 18,
                            ),
                            Text(
                              _weatherData?['current']['uv'].toString() ?? '',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

// Weather for the next two days
                Expanded(
                  child: ListView.builder(
                    itemCount: 2,
                    itemBuilder: (context, index) {
                      final dayData =
                          _weatherData!['forecast']['forecastday'][index + 1];
                      final date = DateTime.parse(dayData['date']);
                      final englishFormattedDate =
                          DateFormat('EEEE', 'en_US').format(date);

                      return FutureBuilder<String>(
                        future: translateToPolish(englishFormattedDate),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return ListTile(title: CircularProgressIndicator());
                          } else if (snapshot.hasError || !snapshot.hasData) {
                            return ListTile(
                                title: Text('Error: ${snapshot.error}'));
                          } else {
                            final translatedDayOfWeek = snapshot.data!;
                            final formattedDate =
                                DateFormat('d MMMM', 'pl_PL').format(date);
                            final fullFormattedDate =
                                '$translatedDayOfWeek, $formattedDate';

                            return Card(
                              margin: EdgeInsets.all(8.0),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                leading: Image.network(
                                    'https:${dayData['day']['condition']['icon']}'),
                                title: Text(fullFormattedDate,
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                      dayData['day']['condition']['text'],
                                      style: TextStyle(fontSize: 16)),
                                ),
                                trailing: Text(
                                    '${dayData['day']['avgtemp_c']}°C',
                                    style: TextStyle(fontSize: 24)),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

Future<List<String>> searchCity(String cityName) async {
  try {
    final response = await http.get(
      Uri.parse(
          'http://api.weatherapi.com/v1/search.json?key=bad6992f8a184659840180617222012&q=$cityName'),
    );
    if (response.statusCode == 200) {
      final results = jsonDecode(response.body) as List;
      return results.map((result) => result['name'].toString()).toList();
    } else {
      throw Exception('Failed to search city');
    }
  } catch (e) {
    throw Exception('Failed to search city: $e');
  }
}

class CitySearchDelegate extends SearchDelegate<String> {
  final Future<List<String>> Function(String cityName) searchCity;

  CitySearchDelegate({required this.searchCity});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: query.isEmpty ? Future.value([]) : searchCity(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(snapshot.data![index]),
                onTap: () {
                  close(context, snapshot.data![index]);
                },
              );
            },
          );
        }
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return query.isEmpty
        ? Container()
        : FutureBuilder<List<String>>(
            future: searchCity(query),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError || !snapshot.hasData) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(snapshot.data![index]),
                      onTap: () {
                        query = snapshot.data![index];
                        showResults(context);
                      },
                    );
                  },
                );
              }
            },
          );
  }
}

Future<String> translateToPolish(String text) async {
  final translator = GoogleTranslator();
  final translation = await translator.translate(text, to: 'pl');
  return translation.text;
}

Widget _buildUvIndexChart(Map<String, dynamic> weatherData) {
  final double uvIndex = weatherData?['current']['uv'] ?? 0.0;

  return Container(
    height: 200,
    width: 250,
    child: SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(minimum: 0, maximum: 12),
      series: <ChartSeries>[
        ColumnSeries<UvIndexData, String>(
          dataSource: [
            UvIndexData('UV', uvIndex),
          ],
          xValueMapper: (UvIndexData data, _) => data.x,
          yValueMapper: (UvIndexData data, _) => data.y,
          pointColorMapper: (UvIndexData data, _) => Colors.orange,
          enableTooltip: true,
        ),
      ],
    ),
  );
}

class UvIndexData {
  final String x;
  final double y;

  UvIndexData(this.x, this.y);
}
