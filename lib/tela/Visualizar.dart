import 'package:comandas_app/model/Mesa.dart';
import 'package:comandas_app/model/Parametro.dart';
import 'package:comandas_app/res/CustomColors.dart';
import 'package:comandas_app/tela/Adicionar.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/ItemMesa.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Visualizar(0)
  ));
}

class Visualizar extends StatefulWidget {

  int _numMesa = 0;

  Visualizar(this._numMesa);

  @override
  _VisualizarState createState() => _VisualizarState();
}

class _VisualizarState extends State<Visualizar> {

  Color _corLaranjaSF = const Color(0xffff6900);
  Color _corMarromSF = const Color(0xff3d2314);

  int _parametro_tipo_visualizacao = 0; //0 - CARD | 1 - LISTA | ALTERADO SEMPRE QUE É SELECIONADO OUTRA OPÇÃO NAS CONFIGURAÇÕES

  bool _visibilityCard = false;
  bool _visibilityProgress = true;
  bool _visibilityList = false;

  final List <ItemMesa> _listaItensMesa = [];

  _recuperar_itens_mesa() async{
    _listaItensMesa.clear();
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("itens-mesa/" + widget._numMesa.toString()).get();
    if (snapshot.exists) {
      final json = snapshot.value as List;
      for(DataSnapshot ds in snapshot.children)
      {
        ItemMesa _itemLista = ItemMesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = ItemMesa.fromJson(json);

        //teste para verificar se já existe esse item na lista. Caso exista, somamos as quantidades
        ItemMesa item = ItemMesa();
        if(_listaItensMesa.firstWhere((it) => it.desc_item == _itemLista.desc_item, orElse: () => item) != item && _listaItensMesa.firstWhere((it) => it.obs_adici == _itemLista.obs_adici, orElse: () => item) != item)
        {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
          ItemMesa _ja_existe = _listaItensMesa.firstWhere((it) => it.desc_item == _itemLista.desc_item && it.obs_adici == _itemLista.obs_adici);
          int _indice = _listaItensMesa.indexOf(_ja_existe);
          num _novo_valor = _ja_existe.valor_tot + _itemLista.valor_tot;
          int _nova_qtd = _ja_existe.qtd + _itemLista.qtd;
          _ja_existe.valor_tot = _novo_valor;
          _ja_existe.qtd = _nova_qtd;
          _listaItensMesa[_indice] = _ja_existe;
          print("teste");
        }
        else{
          _listaItensMesa.add(_itemLista);
        }
      }
    }
    setState(() {
      if(_listaItensMesa.length > 0)
      {
        if(_parametro_tipo_visualizacao == 0) {
          _visibilityCard = true;
          _visibilityList = false;
          _visibilityProgress = false;
        }

        else{
          _visibilityCard = false;
          _visibilityList = true;
          _visibilityProgress = false;
        }
      }
      else
      {
        _visibilityProgress = false;
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _recuperar_itens_mesa();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: CustomColors().corMarromSF,
        title: Text("Itens da Mesa " + widget._numMesa.toString(), style: TextStyle(color: Colors.white)),
        actions:[
          PopupMenuButton(
              icon: Icon(Icons.list, color: Color(0xffff6900),),
              itemBuilder: (context){
                return [
                  PopupMenuItem<int>(
                    value: 0,
                    child: Text("Grade"),
                  ),
                  PopupMenuItem<int>(
                    value: 1,
                    child: Text("Lista"),
                  ),
                ];
              },
              onSelected:(value){
                if(_listaItensMesa.length > 0)
                {
                  if(value == 0){
                    setState(() {
                      _parametro_tipo_visualizacao = 0;
                      _visibilityList = false;
                      _visibilityCard = true;
                    });
                  }
                  else{
                    setState(() {
                      _parametro_tipo_visualizacao = 1;
                      _visibilityList = true;
                      _visibilityCard = false;
                    });
                  }
                }
              }
          ),
        ],
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            Visibility(
                visible: _visibilityProgress,
                child: Expanded(
                    child: Container(
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          strokeWidth: 10,
                          backgroundColor: CustomColors().corMarromSF,
                          valueColor: AlwaysStoppedAnimation<Color> (CustomColors().corLaranjaSF),
                        )
                    )
                )
            ),
            Visibility(
                visible: _visibilityCard,
                child: Expanded(
                    child: ScrollConfiguration(
                        behavior: ScrollBehavior(),
                        child: GlowingOverscrollIndicator(
                            axisDirection: AxisDirection.down,
                            color: _corLaranjaSF.withOpacity(0.20),
                            child:GridView.count(
                              padding: EdgeInsets.fromLTRB(4, 4, 4, 48),
                              scrollDirection: Axis.vertical,
                              shrinkWrap: true,
                              crossAxisCount: 2,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              children: List.generate(_listaItensMesa.length, (index) {
                                return Card(
                                    elevation: 4,
                                    child: InkWell(
                                        onTap: (){
                                          setState(() {
                                            //mostrarDialogoMesa(index + 1);
                                          });
                                        },
                                        child: Container(
                                            decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                border: Border.all(
                                                    color: Colors.deepOrange
                                                ),
                                                borderRadius: BorderRadius.all(Radius.circular(5))
                                            ),
                                            margin: EdgeInsets.all(8),
                                            child: Stack(
                                                children: <Widget>[
                                                  Column(
                                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                    children: <Widget>[
                                                      Padding(
                                                        padding: EdgeInsets.fromLTRB(2, 4, 2, 2),
                                                        child: Text(
                                                          _listaItensMesa[index].desc_item,
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            color: _corMarromSF,
                                                            fontSize: (18),
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: EdgeInsets.fromLTRB(2, 2, 2, 2),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: <Widget>[
                                                            Expanded(
                                                              child: Text(
                                                                _listaItensMesa[index].qtd.toString() + " x " + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaItensMesa[index].valor_uni),
                                                                textAlign: TextAlign.center,
                                                                style: TextStyle(
                                                                  color: _corLaranjaSF,
                                                                  fontSize: (16),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: EdgeInsets.fromLTRB(2, 2, 4, 2),
                                                        child: Text(
                                                          "Total: " + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaItensMesa[index].valor_tot),
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            color: _corMarromSF,
                                                            fontSize: (20),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ]
                                            )
                                        )
                                    )
                                );
                              }),
                            )
                        )
                    )
                )
            ),
            Visibility(
                visible: _visibilityList,
                child: Expanded(
                  child: ScrollConfiguration(
                      behavior: ScrollBehavior(),
                      child: GlowingOverscrollIndicator(
                          axisDirection: AxisDirection.down,
                          color: _corLaranjaSF.withOpacity(0.20),
                          child:ListView.builder(
                            itemCount: _listaItensMesa.length,
                            shrinkWrap: true,
                            padding: EdgeInsets.fromLTRB(4, 4, 4, 48),
                            scrollDirection: Axis.vertical,
                            itemBuilder: (BuildContext, index){
                              return Card(
                                child: ListTile(
                                  leading:  CircleAvatar(
                                    backgroundColor: _corLaranjaSF,
                                    child: Icon(
                                      Icons.forward, color: Colors.white,
                                    ),
                                  ),
                                  title: Padding(
                                    padding: EdgeInsets.fromLTRB(0, 4, 0, 2),
                                    child: Text(
                                      _listaItensMesa[index].desc_item,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _corMarromSF,
                                        fontSize: (14),
                                      ),
                                    ),
                                  ),
                                  subtitle: Column(
                                    children: <Widget>[
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(0, 2, 0, 2),
                                        child: Text(
                                          _listaItensMesa[index].qtd.toString() + " x " + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaItensMesa[index].valor_uni),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _corLaranjaSF,
                                            fontSize: (16),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(0, 2, 0, 4),
                                        child: Text(
                                          "Total: " + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaItensMesa[index].valor_tot),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: _corMarromSF,
                                              fontSize: (16),
                                              fontWeight: FontWeight.w700
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      )
                  )
                )
            ),
          ],
        ),
      )
    );
  }
}
