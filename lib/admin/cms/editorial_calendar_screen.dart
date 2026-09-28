import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class EditorialCalendarScreen extends StatefulWidget {
  const EditorialCalendarScreen({super.key});
  @override State<EditorialCalendarScreen> createState() => _EditorialCalendarScreenState();
}

class _EditorialCalendarScreenState extends State<EditorialCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  List<Map<String,dynamic>> _items = [];

  @override void initState(){super.initState();_load();}

  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      final start=DateTime(_month.year,_month.month).toUtc().toIso8601String();
      final end=DateTime(_month.year,_month.month+1).toUtc().toIso8601String();
      final rows=await SupabaseService.client.from('publishing_items')
        .select('id,title,status,scheduled_at,content_type,byline')
        .gte('scheduled_at',start).lt('scheduled_at',end).order('scheduled_at');
      if(mounted)setState(()=>_items=List<Map<String,dynamic>>.from(rows));
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Calendar could not load: '+e.toString())));
    } finally { if(mounted)setState(()=>_loading=false); }
  }

  List<Map<String,dynamic>> _forDay(int day) {
    return _items.where((x){
      final d=DateTime.tryParse(x['scheduled_at']?.toString()??'')?.toLocal();
      return d!=null && d.day==day;
    }).toList();
  }

  @override Widget build(BuildContext context) {
    final first=DateTime(_month.year,_month.month,1);
    final days=DateTime(_month.year,_month.month+1,0).day;
    final leading=(first.weekday-1)%7;
    final cells=<Widget>[];
    for(var i=0;i<leading;i++)cells.add(const SizedBox.shrink());
    for(var day=1;day<=days;day++){
      final items=_forDay(day);
      cells.add(_dayCell(day,items));
    }
    while(cells.length<42)cells.add(const SizedBox.shrink());
    return Scaffold(
      appBar:NileAppBar(title:'Editorial Calendar',actions:[
        IconButton(onPressed:()=>context.push('/admin/cms/publishing'),icon:const Icon(Icons.edit_calendar_outlined),tooltip:'Publishing Studio'),
        IconButton(onPressed:_load,icon:const Icon(Icons.refresh)),
      ]),
      body:Padding(
        padding:const EdgeInsets.all(NileSpacing.md),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[
            IconButton(onPressed:(){setState(()=>_month=DateTime(_month.year,_month.month-1));_load();},icon:const Icon(Icons.chevron_left)),
            Expanded(child:Text(MaterialLocalizations.of(context).formatMonthYear(_month),textAlign:TextAlign.center,style:NileTypography.titleLarge)),
            IconButton(onPressed:(){setState(()=>_month=DateTime(_month.year,_month.month+1));_load();},icon:const Icon(Icons.chevron_right)),
          ]),
          const SizedBox(height:10),
          if(_loading)const LinearProgressIndicator(),
          const SizedBox(height:8),
          Row(children:['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((d)=>Expanded(child:Padding(padding:const EdgeInsets.all(4),child:Text(d,textAlign:TextAlign.center,style:NileTypography.labelSmall)))).toList()),
          Expanded(child:GridView.count(
            crossAxisCount:7,childAspectRatio:1.05,crossAxisSpacing:4,mainAxisSpacing:4,
            children:cells,
          )),
        ]),
      ),
    );
  }

  Widget _dayCell(int day,List<Map<String,dynamic>> items){
    return Card(
      margin:EdgeInsets.zero,
      child:InkWell(
        onTap:items.isEmpty?null:()=>_showDay(day,items),
        child:Padding(padding:const EdgeInsets.all(6),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(day.toString(),style:NileTypography.labelSmall),
          const SizedBox(height:4),
          Expanded(child:ListView(
            physics:const NeverScrollableScrollPhysics(),
            children:items.take(3).map((x)=>Container(
              margin:const EdgeInsets.only(bottom:3),padding:const EdgeInsets.symmetric(horizontal:5,vertical:3),
              decoration:BoxDecoration(color:NileColors.primaryContainer,borderRadius:BorderRadius.circular(6)),
              child:Text(x['title']?.toString()??'Untitled',maxLines:2,overflow:TextOverflow.ellipsis,style:NileTypography.labelSmall.copyWith(color:NileColors.primary)),
            )).toList(),
          )),
          if(items.length>3)Text('+'+(items.length-3).toString()+' more',style:NileTypography.labelSmall),
        ])),
      ),
    );
  }

  Future<void> _showDay(int day,List<Map<String,dynamic>> items) async {
    await showDialog<void>(context:context,builder:(_)=>AlertDialog(
      title:Text('Publishing — '+day.toString()+' '+MaterialLocalizations.of(context).formatMonthYear(_month)),
      content:SizedBox(width:620,height:420,child:ListView.separated(
        itemCount:items.length,separatorBuilder:(_,__)=>const Divider(),
        itemBuilder:(_,i){
          final x=items[i];
          final dt=DateTime.tryParse(x['scheduled_at']?.toString()??'')?.toLocal();
          return ListTile(
            leading:const Icon(Icons.event_outlined),
            title:Text(x['title']?.toString()??'Untitled'),
            subtitle:Text((dt?.toString()??'')+' · '+(x['content_type']?.toString()??'content')+' · '+(x['status']?.toString()??'')),
            trailing:Text(x['byline']?.toString()??''),
          );
        },
      )),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))],
    ));
  }
}
