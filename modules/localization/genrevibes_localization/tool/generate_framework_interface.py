#!/usr/bin/env python3
"""Generate interface coverage from the installed Flutter SDK; no translations."""
from pathlib import Path
import argparse,json,re
p=argparse.ArgumentParser();p.add_argument('flutter',type=Path);args=p.parse_args()
package=Path(__file__).resolve().parents[1]
source=args.flutter/'packages/flutter_localizations/lib/src/l10n'
keys={};classes=[];required=set()
for kind in ['material','cupertino','widgets']:
 name=kind.capitalize();text=(source/f'generated_{kind}_localizations.dart').read_text()
 cls=f'{name}LocalizationEn' if kind!='widgets' else 'WidgetsLocalizationEn'
 start=text.index(f'class {cls} extends ');end=text.index('\n}\n',start)+2;body=text[start:end]
 getters=re.findall(r'  @override\n  ([\w?]+) get (\w+) => ([\s\S]*?);',body)
 expressions=[]
 for typ,key,expression in getters:
  if typ in ['String','String?']:
   if key=='dateHelpText':value='bundle.dateHelpText'
   elif key=='datePickerDateOrderString':value='bundle.dateOrder'
   elif key=='datePickerDateTimeOrderString':value="'date_time_dayPeriod'"
   elif typ=='String?':value=f"bundle.labels['{key}']"
   else:value=f"bundle.label('{key}')";required.add(key)
   if expression!='null' and key not in ['dateHelpText','datePickerDateOrderString','datePickerDateTimeOrderString']:
    raw=expression[1:] if expression.startswith('r') else expression
    quote=raw[0];literal=raw[1:-1]
    if not expression.startswith('r'):
     literal=literal.replace('\\'+quote,quote).replace('\\n','\n').replace('\\$', '$').replace('\\\\','\\')
    keys.setdefault(key,literal)
  elif key=='scriptCategory':value='bundle.tallScript ? ScriptCategory.tall : ScriptCategory.englishLike'
  elif key=='timeOfDayFormatRaw':value='bundle.use24HourFormat ? TimeOfDayFormat.HH_colon_mm : TimeOfDayFormat.h_colon_mm_space_a'
  else:raise ValueError((kind,typ,key,expression))
  expressions.append(f"  @override\n  {typ} get {key} => {value};")
 if kind=='widgets':constructor='  _AppWidgets(this.bundle) : super(bundle.direction);'
 else:
  params=re.findall(r'required super\.(\w+)',body[:body.index('  @override')])
  constructor='  _App'+name+'({required this.bundle, required super.localeName, '+', '.join('required super.'+param for param in params)+'});'
 classes.append('class _App'+name+' extends Global'+name+'Localizations {\n'+constructor+'\n  final FrameworkLocaleBundle bundle;\n\n'+'\n\n'.join(expressions)+'\n}')
output='''// Interface coverage derived from Flutter's generated localization API.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Flutter's BSD license is retained in licenses/flutter.txt.
part of 'framework_localizations.dart';

'''+ '\n\n'.join(classes)+'\n\nconst requiredFrameworkLabels = <String>{\n'+''.join("  '"+key+"',\n" for key in sorted(required))+'};\n'
(package/'lib/src/framework_interface.g.dart').write_text(output)
# This is an input template, not an English-filled translation.
output=Path.cwd()/'lunaris_network_app/lib/l10n/framework'
output.mkdir(exist_ok=True)
(output/'en.json').write_text(json.dumps(keys,ensure_ascii=False,indent=2)+'\n')
license_dir=package/'licenses';license_dir.mkdir(exist_ok=True)
(license_dir/'flutter.txt').write_text((args.flutter/'LICENSE').read_text())
print('Framework labels:',len(keys),'required:',len(required))
