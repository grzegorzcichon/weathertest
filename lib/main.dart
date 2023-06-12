import 'dart:async';
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
theme: ThemeData(
primarySwatch: Colors.blue,
brightness: _isDarkMode ? Brightness.dark : Brightness.light,
scaffoldBackgroundColor: _isDarkMode ? Colors.black : Colors.white,
appBarTheme: AppBarTheme(
brightness: _isDarkMode ? Brightness.dark : Brightness.light,
),
textTheme: TextTheme(
bodyText2: TextStyle(
color: _isDarkMode ? Colors.white : Colors.black,
),
),
),
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
Timer? _refreshTimer;
bool _isDarkMode = false;

@override
void initState() {
super.initState();
_getSavedCityName().then((savedCityName) {
if (savedCityName != null) {
_fetchWeatherData(savedCityName);
} else {
_fetchWeatherData('Częstochowa');
}
});// Ustawienie timera na 30 minut
_refreshTimer = Timer.periodic(Duration(minutes: 30), (timer) {
  _getSavedCityName().then((savedCityName) {
    if (savedCityName != null) {
      _fetchWeatherData(savedCityName);
    }
  });
});
}

@override
void dispose() {
_refreshTimer?.cancel();
super.dispose();
}

Future<void> _fetchWeatherData(String cityName) async {
try {
final response = await http.get(
Uri.parse(
'http://api.weatherapi.com/v1/forecast.json?key=bad6992f8a184659840180617222012&q=$cityName&days=3&aqi=no&alerts=no'),
);  if (response.statusCode == 200) {
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

Future<void> _saveCityName(String cityName)
async {
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
Switch(
value: _isDarkMode,
onChanged: (value) {
setState(() {
_isDarkMode = value;
});
},
activeColor: _isDarkMode ? Colors.white : Colors.black,
inactiveThumbColor: _isDarkMode ? Colors.black : Colors.white,
inactiveTrackColor: _isDarkMode ? Colors.grey : Colors.grey.shade300,
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
fontSize: 20,
fontWeight: FontWeight.bold,
color: _isDarkMode ? Colors.white : Colors.black,
),
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
style: TextStyle(
fontSize: 48,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
// Weather description
Text(
_weatherData!['current']['condition']['text'],
style: TextStyle(
fontSize: 24,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
// Wind speed
Text(
'Wiatr: ${_weatherData!['current']['wind_kph']} km/h',
style: TextStyle(
fontSize: 18,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
// Humidity
Text(
'Wilgotność: ${_weatherData!['current']['humidity']}%',
style: TextStyle(
fontSize: 18,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
// Precipitation
GestureDetector(
onTap: () {
final maxPrecip =_weatherData!['forecast']['forecastday'][0]['hour']
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
backgroundColor: _isDarkMode ? Colors.black : Colors.white,
plotAreaBorderColor: Colors.transparent,
zoomPanBehavior: ZoomPanBehavior(
enablePinching: true,
enablePanning: true,
enableMouseWheelZooming: true,
),
primaryXAxis: CategoryAxis(
majorGridLines: MajorGridLines(width: 0),
axisLine: AxisLine(width: 0),
labelStyle: TextStyle(
color: _isDarkMode ? Colors.white : Colors.black,
fontSize: 12,
),
labelRotation: -45,
),
primaryYAxis: NumericAxis(
minimum: 0,
axisLine: AxisLine(width: 0),
majorTickLines: MajorTickLines(size: 0),
majorGridLines: MajorGridLines(
color: _isDarkMode ? Colors.grey.shade800 : Colors.grey),
title: AxisTitle(
text: 'Opady (mm)',
textStyle: TextStyle(
fontSize: 14,
fontWeight: FontWeight.bold,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
labelStyle: TextStyle(
color: _isDarkMode ? Colors.white : Colors.black,
fontSize: 12,
),
),
series: <ChartSeries>[
LineSeries<dynamic, String>(
dataSource: _weatherData!['forecast']['forecastday'][0]['hour'],
xValueMapper: (hourData, _) => hourData['time'].substring(11, 16),
yValueMapper: (hourData, _) => hourData['precip_mm'],
name: 'Opady',
color: Colors.deepPurple,
width: 2,
markerSettings: MarkerSettings(isVisible: false),
dataLabelSettings: DataLabelSettings(isVisible: false),
)
],
),
),
),
actions: [
Text(
'Największe opady: ${maxPrecip['precip_mm']} mm o godzinie ${maxPrecip['time'].substring(11, 16)}',
style: TextStyle(
fontSize: 14,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
TextButton(
onPressed: () {
Navigator.of(context).pop();
},
child: Text(
'Zamknij',
style: TextStyle(
color: _isDarkMode ? Colors.white : Colors.black,
),
),
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
style: TextStyle(
fontSize: 18,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
SizedBox(width: 4),
// Raindrop icon
Icon(
Icons.water_drop_sharp,
size: 24,
color: _isDarkMode ? Colors.white : Colors.black,
),
],
),// Pressure
Text(
'Ciśnienie: ${_weatherData!['current']['pressure_mb']} hPa',
style: TextStyle(
fontSize: 18,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
// Visibility
Text(
'Widoczność: ${_weatherData!['current']['vis_km']} km',
style: TextStyle(
fontSize: 18,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
// Cloud cover
Text(
'Zachmurzenie: ${_weatherData!['current']['cloud']}%',
style: TextStyle(
fontSize: 18,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
// Feels like
Text(
'Odczuwalna temperatura: ${_weatherData!['current']['feelslike_c']}°C',
style: TextStyle(
fontSize: 18,
color: _isDarkMode ? Colors.white : Colors.black,
),
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
child: Text(
'Zamknij',
style: TextStyle(
color: _isDarkMode ? Colors.white : Colors.black,
),
),
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
Icon(
_isDarkMode ? Icons.wb_sunny : Icons.nights_stay,
size: 24,
color: _isDarkMode ? Colors.white : Colors.black,
),
Text(
'Indeks UV: ${_weatherData?['current']['uv'].toString() ?? ''}',
style: TextStyle(
fontSize: 18,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
],
),
),
],
),
),            // Weather for the next two days
            Expanded(
              child: ListView.builder(
                itemCount: 2,
                itemBuilder: (context, index) {
                  final dayData = _weatherData!['forecast']['forecastday'][index + 1];
                  final date = DateTime.parse(dayData['date']);
                  final englishFormattedDate = DateFormat('EEEE', 'en_US').format(date);
                  return FutureBuilder<String>(
                    future: translateToPolish(englishFormattedDate),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListTile(title: CircularProgressIndicator());
                      } else if (snapshot.hasError || !snapshot.hasData) {
                        return ListTile(
                          title: Text('Error: ${snapshot.error}'),
                          subtitle: Text(
                            '${dayData['day']['avgtemp_c']}°C',
                            style: TextStyle(
                              fontSize: 24,
                              color: _isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      } else {
                        final translatedDayOfWeek = snapshot.data!;
                        final formattedDate = DateFormat('d MMMM', 'pl_PL').format(date);
                        final fullFormattedDate = '$translatedDayOfWeek, $formattedDate';

                        return Card(
                          margin: EdgeInsets.all(8.0),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.0
, vertical: 8.0),
leading: Image.network(
'https:${dayData['day']['condition']['icon']}',
),
title: Text(
fullFormattedDate,
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
subtitle: Padding(
padding: const EdgeInsets.only(top: 8.0),
child: Text(
dayData['day']['condition']['text'],
style: TextStyle(
fontSize: 16,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
),
trailing: Text(
'${dayData['day']['avgtemp_c']}°C',
style: TextStyle(
fontSize: 24,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
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
close(context, query);
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
final translation = await translator.translate(text, from: 'en', to: 'pl');
return translation.text;
}

Widget _buildUvIndexChart(Map<String, dynamic> weatherData) {
final List<ChartSampleData> uvIndexData = [];
final List<dynamic> forecastDays = weatherData['forecast']['forecastday'];
for (int i = 0; i < forecastDays.length; i++) {
final forecastData = forecastDays[i];
final date = DateTime.parse(forecastData['date']);
final uvIndex = forecastData['day']['uv'];
uvIndexData.add(ChartSampleData(date: date, uvIndex: uvIndex));
}

return Container(
height: 300,
child: SfCartesianChart(
primaryXAxis: DateTimeAxis(
dateFormat: DateFormat('dd MMM'),
intervalType: DateTimeIntervalType.days,
majorGridLines: MajorGridLines(width: 0),
axisLine: AxisLine(width: 0),
labelStyle: TextStyle(
color: _isDarkMode ? Colors.white : Colors.black,
fontSize: 12,
),
),
primaryYAxis: NumericAxis(
minimum: 0,
maximum: 15,
interval: 5,
axisLine: AxisLine(width: 0),
majorTickLines: MajorTickLines(size: 0),
majorGridLines: MajorGridLines(
color: _isDarkMode ? Colors.grey.shade800 : Colors.grey,
),
title: AxisTitle(
text: 'Indeks UV',
textStyle: TextStyle(
fontSize: 14,
fontWeight: FontWeight.bold,
color: _isDarkMode ? Colors.white : Colors.black,
),
),
labelStyle: TextStyle(
color: _isDarkMode ? Colors.white : Colors.black,
fontSize: 12,
),
),
series: <ChartSeries>[
LineSeries<ChartSampleData, DateTime>(
dataSource: uvIndexData,
xValueMapper: (data, _) => data.date,
yValueMapper: (data, _) => data.uvIndex,
name: 'Indeks UV',
color: Colors.orange,
width: 2,
markerSettings: MarkerSettings(isVisible: false),
dataLabelSettings: DataLabelSettings(isVisible: false),
)
],
),
);
}

class ChartSampleData {
ChartSampleData({
required this.date,
required this.uvIndex,
});

final DateTime date;
final double uvIndex;
}