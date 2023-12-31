import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../service/utils_service.dart';

class ConnectPageController extends GetxController {
  final UtilService utilService = UtilService();
  late StreamSubscription serviceStream;
  DateTime dateToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  void setupHeartRateNotifications(List<BluetoothService> services) async {
    int valueOld = 1;
    for (var service in services) {
      // if (service.uuid == Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e')) {
      //   var characteristic = service.characteristics.firstWhere(
      //           (c) => c.uuid == Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'));
      //   characteristic.write([1,12,1,10]);
      // }
      if (service.uuid == Guid('0000180d-0000-1000-8000-00805f9b34fb')) {
        var characteristic = service.characteristics.firstWhere(
            (c) => c.uuid == Guid('00002a37-0000-1000-8000-00805f9b34fb'));

        characteristic.setNotifyValue(true).then((_) {
          serviceStream = characteristic.lastValueStream.listen((data) {
            if (data.isNotEmpty) {
              if (data[1] == 0) {
                if (valueOld != 1) {
                  saveDataToHive({
                    'date': DateTime.now().toString(),
                    'heartRate': valueOld,
                  });
                  postHeartRate(valueOld);
                  saveHistoryToHive(valueOld);
                  valueOld = 1;
                }
              } else {
                valueOld = data[1];
              }
            }
          });
        });
      }
    }
  }

  Future<void> saveDataToHive(Map<String, dynamic> data) async {
    if (Hive.isBoxOpen('heartRateData')) {
      var box = await Hive.openBox('heartRateData');
      if (box.isNotEmpty) {
        final value = box.getAt(box.length - 1);
        final itemDate = DateTime.parse(value['date'].toString().substring(0, 10));
        if (itemDate.isBefore(dateToday)) {
          await box.clear();
        }
      }
      await box.add(data);
    }
  }

  Future<void> saveHistoryToHive(int data) async {
    if (Hive.isBoxOpen('heartRateHistory')) {
      var box = await Hive.openBox('heartRateHistory');
      List<double> hourHeartRateAverage = List.filled(24, 0.0);
      int hour = DateTime.now().hour;
      if (box.isNotEmpty) {
        if(box.get(dateToday.toString()) != null){
          hourHeartRateAverage = box.get(dateToday.toString());
        }
        if (hourHeartRateAverage[hour] == 0.0) {
          hourHeartRateAverage[hour] = data.toDouble();
        } else {
          hourHeartRateAverage[hour] = (data.toDouble() + hourHeartRateAverage[hour]) / 2;
        }
      } else {
        hourHeartRateAverage[hour] = data.toDouble();
      }

      await box.put(dateToday.toString(), hourHeartRateAverage);
    }
  }

  Future<void> saveDeviceToHive(String data) async {
    if (Hive.isBoxOpen('deviceData')) {
      var box = await Hive.openBox('deviceData');
      await box.put('deviceId', data);
    }
  }

  Future<void> postHeartRate(int data) async {
    final connect = GetConnect();
    if (Hive.isBoxOpen('token')) {
      var box = await Hive.openBox('token');
      await connect.post(
          '${utilService.url}/api/vital',
          {
            'heart_rate' : data,
          },
          headers: {
            'Authorization' : 'Bearer ${box.getAt(0)}'
          }
      );
    }

  }
}

