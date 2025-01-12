import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/l10n/app_localizations.dart';

class YearInputFormatter extends TextInputFormatter {
  final RegExp _yearRegex = RegExp(r'^-?\d{0,4}$');
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (_yearRegex.hasMatch(newValue.text)) {
      return newValue;
    } else {
      return oldValue;
    }
  }
}

class MonthInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d+$').hasMatch(text)) return oldValue;
    if (text.length > 2) return oldValue;
    final month = int.tryParse(text);
    if (month == null || month < 1 || month > 12) return oldValue;
    return newValue;
  }
}

class DayInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d+$').hasMatch(text)) return oldValue;
    if (text.length > 2) return oldValue;
    final day = int.tryParse(text);
    if (day == null || day < 1 || day > 31) return oldValue;
    return newValue;
  }
}

Future<Map<String, dynamic>?> showAnnotationInitializationDialog(
  BuildContext context, {
  String? initialTitle,
  String? initialIconName,
  String? initialDate,
  String? initialEndDate,
}) async {
  logger.i('Showing initial form dialog (title, icon, date, endDate).');

  final titleController = TextEditingController(text: initialTitle ?? '');
  String chosenIconName = initialIconName ?? "cross";

  bool showDateFields = false;
  bool showSecondDateFields = false;

  final startMonthOrDayController = TextEditingController();
  final startDayOrMonthController = TextEditingController();
  final startYearController = TextEditingController();

  final endMonthOrDayController = TextEditingController();
  final endDayOrMonthController = TextEditingController();
  final endYearController = TextEditingController();

  return showDialog<Map<String, dynamic>?>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final screenWidth = MediaQuery.of(dialogContext).size.width;
      return StatefulBuilder(
        builder: (context, setState) {
          final loc = AppLocalizations.of(dialogContext)!;
          final localeName = loc.localeName;
          bool isUSLocale = localeName == 'en_US';

          final double containerWidth = screenWidth * 0.5;
          final double smallFieldWidth = containerWidth * 0.1;
          final double yearFieldWidth = containerWidth * 0.15;

          void parseDateString(String dateStr, TextEditingController firstC, TextEditingController secondC, TextEditingController yearC) {
            if (dateStr.isEmpty) return;
            final parts = dateStr.split('-');
            if (parts.length != 3) return;

            final part1 = parts[0];
            final part2 = parts[1];
            final part3 = parts[2];

            // For US: MM-DD-YYYY
            // For non-US: DD-MM-YYYY
            if (isUSLocale) {
              // US: part1=MM, part2=DD, part3=YYYY
              firstC.text = part1; 
              secondC.text = part2;
              yearC.text = part3;
            } else {
              // Non-US: part1=DD, part2=MM, part3=YYYY
              // firstController=day, secondController=month in non-US
              firstC.text = part1;  // Day
              secondC.text = part2; // Month
              yearC.text = part3;   // Year
            }
          }

          String buildDateString({
            required TextEditingController firstController,
            required TextEditingController secondController,
            required TextEditingController yearController,
            required bool isUSLocale,
          }) {
            final firstVal = firstController.text.trim();
            final secondVal = secondController.text.trim();
            final yearVal = yearController.text.trim();

            if (firstVal.isEmpty || secondVal.isEmpty || yearVal.isEmpty) {
              return '';
            }

            // US: MM-DD-YYYY
            // Non-US: DD-MM-YYYY
            if (isUSLocale) {
              return '$firstVal-$secondVal-$yearVal';
            } else {
              return '$firstVal-$secondVal-$yearVal';
            }
          }

          Widget buildDateFields({
            required TextEditingController firstController,
            required TextEditingController secondController,
            required TextEditingController yearController,
          }) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: smallFieldWidth,
                  child: TextField(
                    controller: firstController,
                    decoration: InputDecoration(
                      hintText: isUSLocale ? 'MM' : 'DD',
                      labelText: isUSLocale ? 'Month' : 'Day',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: isUSLocale 
                      ? [MonthInputFormatter()] 
                      : [DayInputFormatter()],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: smallFieldWidth,
                  child: TextField(
                    controller: secondController,
                    decoration: InputDecoration(
                      hintText: isUSLocale ? 'DD' : 'MM',
                      labelText: isUSLocale ? 'Day' : 'Month',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: isUSLocale
                      ? [DayInputFormatter()]   
                      : [MonthInputFormatter()],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: yearFieldWidth,
                  child: TextField(
                    controller: yearController,
                    decoration: const InputDecoration(
                      hintText: 'YYYY',
                      labelText: 'Year',
                    ),
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      YearInputFormatter(),
                    ],
                  ),
                ),
              ],
            );
          }

          // If initial date provided, parse and show
          if (initialDate != null && initialDate.isNotEmpty && !showDateFields) {
            setState(() {
              showDateFields = true;
              parseDateString(initialDate, startMonthOrDayController, startDayOrMonthController, startYearController);
            });
          }

          // If initial end date provided, parse and show second date fields
          if (initialEndDate != null && initialEndDate.isNotEmpty && !showSecondDateFields) {
            setState(() {
              showDateFields = true; // end date implies also start date fields shown
              showSecondDateFields = true;
              parseDateString(initialEndDate, endMonthOrDayController, endDayOrMonthController, endYearController);
            });
          }

          return AlertDialog(
            content: SizedBox(
              width: containerWidth,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            logger.i('Close icon tapped in initial form dialog.');
                            Navigator.of(dialogContext).pop(null);
                          },
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Title:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: titleController,
                      maxLength: 25,
                      decoration: InputDecoration(
                        hintText: 'Max 25 characters',
                        hintStyle: TextStyle(
                          color: Colors.black.withOpacity(0.5),
                        ),
                        counterText: '',
                      ),
                      buildCounter: (context, {required int currentLength, required bool isFocused, required int? maxLength}) {
                        if (maxLength == null) return null;
                        if (currentLength == 0) {
                          return null; 
                        } else {
                          return Text(
                            '$currentLength/$maxLength',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Icon:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/$chosenIconName.png',
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            logger.i('Opening icon selection dialog from initial form dialog.');
                            final selectedIconName = await _showMapboxIconSelectionDialog(dialogContext);
                            logger.i('Icon selection dialog returned: $selectedIconName');
                            if (selectedIconName != null) {
                              setState(() {
                                chosenIconName = selectedIconName;
                              });
                            }
                          },
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        logger.i('Add Date button clicked');
                        setState(() {
                          showDateFields = true;
                        });
                      },
                      child: const Text('Add Date'),
                    ),
                    if (showDateFields) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          buildDateFields(
                            firstController: startMonthOrDayController,
                            secondController: startDayOrMonthController,
                            yearController: startYearController,
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              logger.i('Plus button clicked for interval');
                              setState(() {
                                showSecondDateFields = true;
                              });
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                          ),
                          if (showSecondDateFields) ...[
                            const SizedBox(width: 8),
                            buildDateFields(
                              firstController: endMonthOrDayController,
                              secondController: endDayOrMonthController,
                              yearController: endYearController,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Save'),
                onPressed: () {
                  logger.i('Save pressed in initial form dialog. Returning quickSave=true');
                  String date = '';
                  String endDate = '';
                  if (showDateFields) {
                    date = buildDateString(
                      firstController: startMonthOrDayController,
                      secondController: startDayOrMonthController,
                      yearController: startYearController,
                      isUSLocale: isUSLocale,
                    );
                    if (showSecondDateFields) {
                      endDate = buildDateString(
                        firstController: endMonthOrDayController,
                        secondController: endDayOrMonthController,
                        yearController: endYearController,
                        isUSLocale: isUSLocale,
                      );
                    }
                  }
                  Navigator.of(dialogContext).pop({
                    'title': titleController.text.trim(),
                    'icon': chosenIconName,
                    'date': date,
                    'endDate': endDate,
                    'quickSave': true,
                  });
                },
              ),
              TextButton(
                child: const Text('Continue'),
                onPressed: () {
                  logger.i('Continue pressed in initial form dialog. Returning quickSave=false');
                  String date = '';
                  String endDate = '';
                  if (showDateFields) {
                    date = buildDateString(
                      firstController: startMonthOrDayController,
                      secondController: startDayOrMonthController,
                      yearController: startYearController,
                      isUSLocale: isUSLocale,
                    );
                    if (showSecondDateFields) {
                      endDate = buildDateString(
                        firstController: endMonthOrDayController,
                        secondController: endDayOrMonthController,
                        yearController: endYearController,
                        isUSLocale: isUSLocale,
                      );
                    }
                  }
                  Navigator.of(dialogContext).pop({
                    'title': titleController.text.trim(),
                    'icon': chosenIconName,
                    'date': date,
                    'endDate': endDate,
                    'quickSave': false,
                  });
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<String?> _showMapboxIconSelectionDialog(BuildContext dialogContext) async {
  final mapboxIcons = [
    "cricket",
    "cinema",
  ];

  return showDialog<String>(
    context: dialogContext,
    builder: (iconDialogContext) {
      return AlertDialog(
        title: const Text('Select an Icon'),
        content: SizedBox(
          width: MediaQuery.of(iconDialogContext).size.width * 0.5,
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: mapboxIcons.map((iconName) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(iconDialogContext).pop(iconName);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/$iconName.png',
                      width: 32,
                      height: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(iconName, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}
