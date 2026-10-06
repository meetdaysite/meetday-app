import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/environment.dart';

class GoogleVenueAutocompleteField extends StatefulWidget {
  const GoogleVenueAutocompleteField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCitySelected,
    this.placeholder = 'Search a venue or address',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCitySelected;
  final String placeholder;

  @override
  State<GoogleVenueAutocompleteField> createState() => _GoogleVenueAutocompleteFieldState();
}

class _GoogleVenueAutocompleteFieldState extends State<GoogleVenueAutocompleteField> {
  late final FlutterGooglePlacesSdk _places = FlutterGooglePlacesSdk(
    googleMapsApiKey,
    locale: const Locale('en', 'IN'),
    useNewApi: true,
  );
  TextEditingController? _fieldController;
  int _queryRevision = 0;

  Future<Iterable<AutocompletePrediction>> _getSuggestions(String input) async {
    final query = input.trim();
    final revision = ++_queryRevision;
    if (googleMapsApiKey.isEmpty || query.length < 3) return const [];

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || revision != _queryRevision) return const [];

    try {
      final result = await _places.findAutocompletePredictions(
        query,
        countries: const ['IN'],
      );
      if (!mounted || revision != _queryRevision) return const [];
      return result.predictions;
    } catch (_) {
      return const [];
    }
  }

  void _selectPrediction(AutocompletePrediction prediction) {
    _queryRevision++;
    unawaited(_resolveSelection(prediction));
  }

  Future<void> _resolveSelection(AutocompletePrediction prediction) async {
    var venueName = prediction.primaryText;
    var city = '';
    try {
      final response = await _places.fetchPlace(
        prediction.placeId,
        fields: const [PlaceField.Name, PlaceField.AddressComponents],
      );
      final place = response.place;
      if (place != null) {
        venueName = place.name?.trim().isNotEmpty == true ? place.name!.trim() : venueName;
        city = _cityFromComponents(place.addressComponents);
      }
    } catch (_) {
      // Keep the prediction text usable when place details are unavailable.
    }

    if (!mounted) return;
    _setText(venueName);
    if (city.isNotEmpty) widget.onCitySelected(city);
  }

  void _setText(String value) {
    widget.onChanged(value);
    final fieldController = _fieldController;
    if (fieldController != null && fieldController.text != value) {
      fieldController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  String _cityFromComponents(List<AddressComponent>? components) {
    if (components == null) return '';
    for (final type in const [
      'locality',
      'administrative_area_level_3',
      'administrative_area_level_2',
    ]) {
      for (final component in components) {
        if (component.types.contains(type)) return component.name;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<AutocompletePrediction>(
      initialValue: TextEditingValue(text: widget.value),
      displayStringForOption: (prediction) => prediction.fullText,
      optionsBuilder: (value) => _getSuggestions(value.text),
      onSelected: _selectPrediction,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _fieldController = controller;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: widget.onChanged,
            onSubmitted: (_) => onFieldSubmitted(),
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final predictions = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black, width: 1.5),
              boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: predictions.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final prediction = predictions[index];
                      return ListTile(
                        dense: true,
                        title: Text(prediction.primaryText, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                        subtitle: prediction.secondaryText.isEmpty
                            ? null
                            : Text(prediction.secondaryText, style: GoogleFonts.poppins(fontSize: 9)),
                        onTap: () => onSelected(prediction),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 8, bottom: 5),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Image(
                      image: FlutterGooglePlacesSdk.ASSET_POWERED_BY_GOOGLE_ON_WHITE,
                      height: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}