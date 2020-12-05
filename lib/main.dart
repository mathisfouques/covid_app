import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

void main() => runApp(CovidApp());

class CovidApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material App',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Covid App'),
        ),
        body: Center(
          child: FutureBuilder<List<Country>>(
            future: getAllCountries(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CupertinoActivityIndicator());
              }

              List<Country> countries = snapshot.data;
              countries.sort(
                (c1, c2) => c2.todayCases.compareTo(c1.todayCases),
              );

              return ListView.builder(
                itemCount: countries.length,
                itemBuilder: (context, index) => ListTile(
                  leading: Image.network(
                    countries[index].flagUrl,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      return Container(
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
                        child: child,
                        clipBehavior: Clip.antiAlias,
                      );
                    },
                  ),
                  title: Text(countries[index].country),
                  subtitle: Text("Cas aujourd'hui : ${countries[index].todayCases}, Morts : ${countries[index].todayDeaths}"),
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      backgroundColor: Colors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(countries[index].country, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          CountryGraph(
                            country: countries[index].country,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CountryGraph extends StatelessWidget {
  const CountryGraph({
    Key key,
    this.country,
  }) : super(key: key);

  final String country;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FutureBuilder<CountryHistoricalCases>(
        future: getCountryCases(country),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return CupertinoActivityIndicator();
          }

          List<dynamic> toHandle = snapshot.data.cases.values.toList();
          List<int> newCasesValues = [toHandle[0]];
          int currentSum = 0;

          for (var i = 1; i < toHandle.length; i++) {
            newCasesValues.add(toHandle[i] - currentSum);

            currentSum = toHandle[i];
          }

          Map<String, int> newCases = Map.fromIterables(snapshot.data.cases.keys, newCasesValues);

          List<FlSpot> spotsCases = snapshot.data.cases.entries
              .map((e) => FlSpot(snapshot.data.cases.keys.toList().indexOf(e.key).toDouble(), e.value.toDouble()))
              .toList();
          List<FlSpot> spotsDeaths = snapshot.data.deaths.entries
              .map((e) => FlSpot(snapshot.data.deaths.keys.toList().indexOf(e.key).toDouble(), e.value.toDouble()))
              .toList();
          List<FlSpot> spotsRecovered = snapshot.data.recovered.entries
              .map((e) => FlSpot(snapshot.data.recovered.keys.toList().indexOf(e.key).toDouble(), e.value.toDouble()))
              .toList();
          List<FlSpot> spotsNewCases =
              newCases.entries.map((e) => FlSpot(newCases.keys.toList().indexOf(e.key).toDouble(), e.value.toDouble())).toList();

          return SizedBox(
            width: MediaQuery.of(context).size.width - 50,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: SideTitles(
                      showTitles: true,
                      interval: 100,
                      getTitles: (value) => snapshot.data.cases.keys.elementAt(value.floor()),
                    ),
                    leftTitles: SideTitles(showTitles: true, reservedSize: 50)),
                lineBarsData: [
                  LineChartBarData(
                    barWidth: 3,
                    spots: spotsCases,
                    colors: [Colors.red],
                    isCurved: true,
                    dotData: FlDotData(show: false),
                    //belowBarData: BarAreaData(show: true, colors: [ Colors.red.withOpacity(0.7)]),
                  ),
                  LineChartBarData(
                    barWidth: 2,
                    spots: spotsDeaths,
                    colors: [Colors.green],
                    isCurved: true,
                    dotData: FlDotData(show: false),
                    //belowBarData: BarAreaData(show: true, colors: [Colors.blue.withOpacity(0.7), Colors.red.withOpacity(0.7)]),
                  ),
                  LineChartBarData(
                    barWidth: 2,
                    spots: spotsRecovered,
                    colors: [Colors.black],
                    isCurved: true,
                    dotData: FlDotData(show: false),
                    //belowBarData: BarAreaData(show: true, colors: [Colors.blue.withOpacity(0.7), Colors.red.withOpacity(0.7)]),
                  ),
                  LineChartBarData(
                    barWidth: 2,
                    spots: spotsNewCases,
                    colors: [Colors.blue],
                    isCurved: true,
                    dotData: FlDotData(show: false),
                    //belowBarData: BarAreaData(show: true, colors: [Colors.blue.withOpacity(0.7), Colors.red.withOpacity(0.7)]),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<CountryHistoricalCases> getCountryCases(String e) async {
  Response response = await get('https://disease.sh/v3/covid-19/historical/$e?lastdays=all');

  return CountryHistoricalCases.fromJson(jsonDecode(response.body));
}

Future<List<CountryHistoricalCases>> getAllCountryCases() async {
  Response response = await get('https://disease.sh/v3/covid-19/historical?lastdays=1');

  List<dynamic> list = jsonDecode(response.body);

  return list.map((e) => CountryHistoricalCases.fromJson(e)).toList();
}

Future<List<Country>> getAllCountries() async {
  Response response = await get('https://disease.sh/v3/covid-19/countries?yesterday=true');

  List<dynamic> list = jsonDecode(response.body);

  return list.map((e) => Country.fromJson(e as Map)).toList();
}

class CountryHistoricalCases {
  final String country;
  final Map<String, dynamic> cases;
  final Map<String, dynamic> deaths;
  final Map<String, dynamic> recovered;

  CountryHistoricalCases({
    @required this.cases,
    @required this.country,
    @required this.deaths,
    @required this.recovered,
  });

  factory CountryHistoricalCases.fromJson(Map<String, dynamic> json) {
    return CountryHistoricalCases(
      cases: json['timeline']['cases'],
      deaths: json['timeline']['deaths'],
      recovered: json['timeline']['recovered'],
      country: json['country'],
    );
  }
}

class CountryDayCases {
  final String country;
  final String date;
  final int cases;
  final int deaths;

  CountryDayCases({
    this.country,
    this.date,
    this.cases,
    this.deaths,
  });
}

class Country {
  final String country;
  final String flagUrl;
  final int cases;
  final int deaths;
  final int recovered;
  final int todayCases;
  final int todayDeaths;

  const Country({
    @required this.country,
    @required this.flagUrl,
    @required this.cases,
    @required this.deaths,
    @required this.recovered,
    @required this.todayCases,
    @required this.todayDeaths,
  });

  factory Country.fromJson(Map<String, dynamic> e) {
    try {
      return Country(
          cases: e['cases'],
          deaths: e['deaths'],
          todayCases: e['todayCases'],
          todayDeaths: e['todayDeaths'],
          country: e['country'],
          flagUrl: e['countryInfo']['flag'],
          recovered: e['recovered']);
    } catch (e) {
      print(e);
      throw (e);
    }
  }
}
