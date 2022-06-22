import 'package:comandas_app/model/Mesa.dart';
import 'package:comandas_app/model/Pedido.dart';
import 'package:comandas_app/model/Parametro.dart';
import 'package:comandas_app/res/CustomColors.dart';
import 'package:comandas_app/tela/Adicionar.dart';
import 'package:comandas_app/tela/Mesas.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/ItemMesa.dart';
import 'package:auto_size_text_pk/auto_size_text_pk.dart';
import 'package:flutter/rendering.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Visualizar(0, "", 0, "")
  ));
}

class Visualizar extends StatefulWidget {

  int _numMesa = 0;
  String _identificador = "";
  int _qtd_vias_imprimir = 0;
  String _ip_impressora = "";

  Visualizar(this._numMesa, this._identificador, this._qtd_vias_imprimir, this._ip_impressora);

  @override
  _VisualizarState createState() => _VisualizarState();
}

class _VisualizarState extends State<Visualizar> {

  String _titulo_tela = "";
  num _taxa_pedido = 0;
  Pedido _pedido_editar = Pedido();

  Color _corLaranjaSF = const Color(0xffff6900);
  Color _corMarromSF = const Color(0xff3d2314);

  int _indice_deletar = 0;
  int _parametro_alteracao = 0; //usado para verificar se houve alteração na mesa ao salvar os itens
  int _parametro_tipo_visualizacao = 0; //0 - CARD | 1 - LISTA | ALTERADO SEMPRE QUE É SELECIONADO OUTRA OPÇÃO NAS CONFIGURAÇÕES

  bool _visibilityCard = false;
  bool _visibilityProgress = true;
  bool _visibilityList = false;
  bool _visibilityCardEditar = false;
  bool _visibilityListEditar = false;
  bool _visibilityFAB = false;
  bool _visibilityBtEditar = true;
  bool _visibilityTaxa = false;

  final List <ItemMesa> _listaItensMesa = [];
  final List <ItemMesa> _listaItensMesaBKP = [];
  final List <ItemMesa> _listaItensMesaEditar = [];

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
        _listaItensMesa.add(_itemLista);
        _listaItensMesaBKP.add(_itemLista);
      }
    }
    setState(() {
      _titulo_tela = "Itens da Mesa " + widget._numMesa.toString();
      if(_listaItensMesa.length > 0)
      {
        if(_parametro_tipo_visualizacao == 0) {
          _visibilityCard = true;
          _visibilityList = false;
          _visibilityProgress = false;
          _visibilityCardEditar = false;
          _visibilityListEditar = false;
        }

        else{
          _visibilityCard = false;
          _visibilityList = true;
          _visibilityProgress = false;
          _visibilityCardEditar = false;
          _visibilityListEditar = false;
        }
      }
      else
      {
        _visibilityProgress = false;
      }
    });
  }

  _recuperar_itens_pedido() async{
    Pedido _pedido_recuperado = Pedido();
    final refpedido = FirebaseDatabase.instance.ref();
    final snap = await refpedido.child("pedidos").get();
    if (snap.exists) {
      for(DataSnapshot ds in snap.children)
      {
        Pedido _itemLista = Pedido();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = Pedido.fromJson(json);
        if(_itemLista.identificador == widget._identificador.toString())
          _pedido_recuperado = _itemLista;
      }
    }
    _pedido_editar = _pedido_recuperado;
    _listaItensMesa.clear();
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("itens-pedido/" + widget._identificador.toString()).get();
    if (snapshot.exists) {
      final json = snapshot.value as List;
      for(DataSnapshot ds in snapshot.children)
      {
        ItemMesa _itemLista = ItemMesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = ItemMesa.fromJson(json);
        _listaItensMesa.add(_itemLista);
        _listaItensMesaBKP.add(_itemLista);
      }
    }

    _taxa_pedido = _calcula_valor_taxa(_pedido_recuperado.total);

    setState(() {
      _titulo_tela = "Pedido de " + _pedido_recuperado.nome_cliente;
      if(_listaItensMesa.length > 0)
      {
        if(_parametro_tipo_visualizacao == 0) {
          _visibilityCard = true;
          _visibilityList = false;
          _visibilityProgress = false;
          _visibilityCardEditar = false;
          _visibilityListEditar = false;
          if(_pedido_recuperado.tipo == 1)
            _visibilityTaxa = true;
        }

        else{
          _visibilityCard = false;
          _visibilityList = true;
          _visibilityProgress = false;
          _visibilityCardEditar = false;
          _visibilityListEditar = false;
          if(_pedido_recuperado.tipo == 1)
            _visibilityTaxa = true;
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
    if(widget._numMesa == 0)
      _recuperar_itens_pedido();
    else
      _recuperar_itens_mesa();
  }

  num _calcula_total_itens_existentes_pedido()
  {
    num _total_inserir_mesa = 0;
    for(ItemMesa it in _listaItensMesa)
    {
      _total_inserir_mesa = _total_inserir_mesa + it.valor_tot;
    }
    return _total_inserir_mesa;
  }

  num _calcula_valor_taxa(num total)
  {
    num _total_itens = _calcula_total_itens_existentes_pedido();
    num _taxa = total - _total_itens;
    return _taxa;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: CustomColors().corMarromSF,
        //title: Text(_titulo_tela, style: TextStyle(color: Colors.white)),
        title: AutoSizeText(
          _titulo_tela,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
          maxLines: 1,
          minFontSize: 8,
          overflow: TextOverflow.ellipsis,
        ),
        actions:[
          Visibility(
              visible: _visibilityBtEditar,
              child: IconButton(
                icon: const Icon
                  (Icons.edit, color: Color(0xffff6900),),
                tooltip: 'Editar',
                onPressed: () {
                  setState(() {
                    _editar_itens();
                  });
                },
              ),
          ),
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
                visible: _visibilityTaxa,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                          child: Container(
                              height: 40,
                              color: _corLaranjaSF,
                              child: Align(
                                alignment: Alignment.center,
                                child: Text(
                                  "Taxa: " + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_taxa_pedido),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: (24),
                                  ),
                                ),
                              )
                          )
                      )
                    ]
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
            Visibility(
                visible: _visibilityCardEditar,
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
                              children: List.generate(_listaItensMesaEditar.length, (index) {
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
                                                          _listaItensMesaEditar[index].desc_item,
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
                                                                _listaItensMesaEditar[index].qtd.toString() + " x " + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaItensMesaEditar[index].valor_uni),
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
                                                        child: Align(
                                                            alignment: Alignment.bottomCenter,
                                                            child:IconButton(
                                                                onPressed: ()
                                                                {
                                                                  //deletar o item
                                                                  _indice_deletar = index;
                                                                  _gerar_dialogo_deletar();
                                                                },
                                                                icon: Icon(Icons.delete_forever, color: Colors.red,)
                                                            )
                                                        )
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
                visible: _visibilityListEditar,
                child: Expanded(
                    child: ScrollConfiguration(
                        behavior: ScrollBehavior(),
                        child: GlowingOverscrollIndicator(
                          axisDirection: AxisDirection.down,
                          color: _corLaranjaSF.withOpacity(0.20),
                          child:ListView.builder(
                            itemCount: _listaItensMesaEditar.length,
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
                                      _listaItensMesaEditar[index].desc_item,
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
                                          _listaItensMesaEditar[index].qtd.toString() + " x " + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaItensMesaEditar[index].valor_uni),
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
                                          "Total: " + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaItensMesaEditar[index].valor_tot),
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
                                  trailing: IconButton(
                                    onPressed: ()
                                    {
                                      _indice_deletar = index;
                                      _gerar_dialogo_deletar();
                                    },
                                    alignment: Alignment.bottomCenter,
                                    icon: Icon(Icons.delete_forever, color: Colors.red,),
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
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Visibility(
                  visible: _visibilityFAB,
                  child:FloatingActionButton.extended(
                    onPressed: () {
                      setState(() {
                        if(_listaItensMesa.length > 0)
                        {
                          if(_parametro_tipo_visualizacao == 0) {
                            _visibilityCard = true;
                            _visibilityList = false;
                            _visibilityProgress = false;
                            _visibilityCardEditar = false;
                            _visibilityListEditar = false;
                            _visibilityFAB = false;
                            _visibilityBtEditar = true;
                          }

                          else{
                            _visibilityCard = false;
                            _visibilityList = true;
                            _visibilityProgress = false;
                            _visibilityCardEditar = false;
                            _visibilityListEditar = false;
                            _visibilityFAB = false;
                            _visibilityBtEditar = true;
                          }
                        }
                        else
                        {
                          _visibilityProgress = false;
                        }
                      });
                    },
                    label: Text('Cancelar', style: TextStyle(fontSize: 14)),
                    icon: const Icon(Icons.clear),
                    backgroundColor: Colors.red,
                    splashColor: Colors.white,
                    heroTag: null,
                  ),
                )
            ),
          ),
          Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Visibility(
                  visible: _visibilityFAB,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      if(_parametro_alteracao == 1)
                        _dialogo_salvar_alteracoes();
                      else
                        _retorna_estado_inicial();
                    },
                    label: Text('Salvar', style: TextStyle(fontSize: 14)),
                    icon: const Icon(Icons.check),
                    backgroundColor: Colors.green,
                    splashColor: Colors.white,
                    heroTag: null,
                  ),
                )
              )
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
  _editar_itens()
  {
    setState(() {
      _visibilityCard = false;
      _visibilityList = false;
      _visibilityProgress = true;
      _visibilityCardEditar = false;
      _visibilityListEditar = false;
    });
    _listaItensMesaEditar.clear();
    for(ItemMesa ds in _listaItensMesa)
    {
      ItemMesa _itemLista = ItemMesa();
      _itemLista = ds;
      //dividimos o item repetido, pois pode ser que cada pessoa pagará um item
      if(_itemLista.qtd > 1)
      {
        for(int i = 0; i < _itemLista.qtd; i++)
        {
          ItemMesa _item_dividido = ItemMesa();
          _item_dividido.id_item = _itemLista.id_item;
          _item_dividido.id_mesa = _itemLista.id_mesa;
          _item_dividido.desc_item = _itemLista.desc_item;
          _item_dividido.obs_adici = _itemLista.obs_adici;
          _item_dividido.valor_uni = _itemLista.valor_uni;
          _item_dividido.valor_tot = _itemLista.valor_uni;
          _item_dividido.qtd = 1;

          _listaItensMesaEditar.add(_item_dividido);
        }
      }
      else{
        _listaItensMesaEditar.add(_itemLista);
      }
    }

    setState(() {
      if(_listaItensMesa.length > 0)
      {
        if(_parametro_tipo_visualizacao == 0) {
          _visibilityCard = false;
          _visibilityList = false;
          _visibilityProgress = false;
          _visibilityCardEditar = true;
          _visibilityListEditar = false;
          _visibilityFAB = true;
          _visibilityBtEditar = false;
        }

        else{
          _visibilityCard = false;
          _visibilityList = false;
          _visibilityProgress = false;
          _visibilityCardEditar = false;
          _visibilityListEditar = true;
          _visibilityFAB = true;
          _visibilityBtEditar = false;
        }
      }
      else
      {
        _visibilityProgress = false;
      }
    });
  }
  _dialogo_salvar_alteracoes()
  {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text('Alterar Itens'),
            content: const Text('Deseja realmente salvar as alterações realizadas nos itens da mesa?'),
            actions: [
              TextButton(
                  onPressed: () {
                    if(_parametro_alteracao == 1)//algum item foi removido
                    {
                      if(widget._numMesa == 0)
                        _altera_itens_pedido();
                      else
                        _altera_itens_mesa();
                    }
                    else
                      _retorna_estado_inicial();
                    // Close the dialog
                    Navigator.of(context).pop();
                  },
                  child: const Text('Sim')),
              TextButton(
                  onPressed: () {
                    // Close the dialog
                    Navigator.of(context).pop();
                  },
                  child: const Text('Não'))
            ],
          );
        });
  }
  _gerar_dialogo_deletar()
  {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text('Remover Item'),
            content: const Text('Deseja realmente remover este item da mesa?'),
            actions: [
              TextButton(
                  onPressed: () {
                    _listaItensMesaEditar.removeAt(_indice_deletar);
                    _parametro_alteracao = 1;
                    _recarrega_lista_itens_editar();
                    // Close the dialog
                    Navigator.of(context).pop();
                  },
                  child: const Text('Sim')),
              TextButton(
                  onPressed: () {
                    // Close the dialog
                    Navigator.of(context).pop();
                  },
                  child: const Text('Não'))
            ],
          );
        });
  }
  _recarrega_lista_itens_editar(){
    setState(() {
      if(_listaItensMesa.length > 0)
      {
        if(_parametro_tipo_visualizacao == 0) {
          _visibilityCard = false;
          _visibilityList = false;
          _visibilityProgress = false;
          _visibilityCardEditar = true;
          _visibilityListEditar = false;
          _visibilityFAB = true;
          _visibilityBtEditar = false;
        }

        else{
          _visibilityCard = false;
          _visibilityList = false;
          _visibilityProgress = false;
          _visibilityCardEditar = false;
          _visibilityListEditar = true;
          _visibilityFAB = true;
          _visibilityBtEditar = false;
        }
      }
      else
      {
        _visibilityProgress = false;
      }
    });
  }

  _retorna_estado_inicial(){
    setState(() {
      if(_listaItensMesa.length > 0)
      {
        if(_parametro_tipo_visualizacao == 0) {
          _visibilityCard = true;
          _visibilityList = false;
          _visibilityProgress = false;
          _visibilityCardEditar = false;
          _visibilityListEditar = false;
          _visibilityFAB = false;
          _visibilityBtEditar = true;
        }

        else{
          _visibilityCard = false;
          _visibilityList = true;
          _visibilityProgress = false;
          _visibilityCardEditar = false;
          _visibilityListEditar = false;
          _visibilityFAB = false;
          _visibilityBtEditar = true;
        }
      }
      else
      {
        _visibilityProgress = false;
      }
    });
  }


  _altera_itens_mesa() async{
    mostrarDialogoSalvando();
    Mesa _mesa_salvar = Mesa();
    Mesa _mesa_recuperada = Mesa();
    final refmesa = FirebaseDatabase.instance.ref();
    final snapshot = await refmesa.child("mesas/" + widget._numMesa.toString()).get();
    if (snapshot.exists) {
      final json = snapshot.value as Map<dynamic, dynamic>;
      _mesa_recuperada = Mesa.fromJson(json);
    }
    _listaItensMesa.clear();
    int _ult_id_registrado = 0;
    for(ItemMesa ds in _listaItensMesaEditar) //ajuste de listagem de itens da mesa
    {
      ItemMesa _itemLista = ItemMesa();
      _itemLista = ds;
      //teste para verificar se já existe esse item na lista. Caso exista, somamos as quantidades
      if(_listaItensMesa.length > 0)
      {
        String desc_item_atual = _itemLista.desc_item;
        String obs_item_atual = _itemLista.obs_adici;
        int indice_encontrado = -1;
        for(int i = 0; i < _listaItensMesa.length; i++)
        {
          for(int y = 0; y < _listaItensMesa.length; y++)
            {
              if(_listaItensMesa[y].desc_item == desc_item_atual && _listaItensMesa[y].obs_adici == obs_item_atual)
              {
                indice_encontrado = y;
              }
            }
          if(indice_encontrado != -1)
          {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
            ItemMesa _ja_existe = _listaItensMesa[indice_encontrado];
            num _novo_valor = _ja_existe.valor_tot + _itemLista.valor_tot;
            int _nova_qtd = _ja_existe.qtd + _itemLista.qtd;
            _ja_existe.valor_tot = _novo_valor;
            _ja_existe.qtd = _nova_qtd;
            _listaItensMesa[indice_encontrado] = _ja_existe;
            break;
          }
          else{
            _itemLista.id_item = _ult_id_registrado + 1;
            _ult_id_registrado = _itemLista.id_item;
            _listaItensMesa.add(_itemLista);
            break;
          }
        }
      }
      else
      {
        _itemLista.id_item = _ult_id_registrado + 1;
        _ult_id_registrado = _itemLista.id_item;
        _listaItensMesa.add(_itemLista);
      }
    }
    //exclui a lista atual da mesa
    await FirebaseDatabase.instance.ref().child('itens-mesa').child(widget._numMesa.toString()).remove();
    //carrega a nova lista
    final ref = FirebaseDatabase.instance.ref("itens-mesa/" + widget._numMesa.toString());
    for(int i = 1; i <= _listaItensMesa.length; i++)
    {
      int _id_registrar = i;
      final json = _listaItensMesa[i-1].toJson();
      await ref.child(_id_registrar.toString()).set(json);
    }
    //atualiza o total da mesa
    num _total_inserir_mesa = _calcula_total_inserir_mesa();
    if(_total_inserir_mesa > 0)
      {
        _mesa_salvar.total = _total_inserir_mesa;
        _mesa_salvar.identificador = _mesa_recuperada.identificador;
        _mesa_salvar.status = 1;
        _mesa_salvar.numero = widget._numMesa;
      }
    else
      {
        _mesa_salvar.total = _total_inserir_mesa;
        _mesa_salvar.identificador = "";
        _mesa_salvar.status = 0;
        _mesa_salvar.numero = widget._numMesa;
      }
    final json = _mesa_salvar.toJson();
    final ref_mesa = FirebaseDatabase.instance.ref("mesas/" + _mesa_salvar.numero.toString());
    await ref_mesa.set(json);
    //retornamos a tela das mesas
    Navigator.of(context).pop();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Mesas()
        )
    );
  }

  _altera_itens_pedido() async{
    mostrarDialogoSalvando();

    _listaItensMesa.clear();
    int _ult_id_registrado = 0;
    for(ItemMesa ds in _listaItensMesaEditar) //ajuste de listagem de itens da mesa
        {
      ItemMesa _itemLista = ItemMesa();
      _itemLista = ds;
      //teste para verificar se já existe esse item na lista. Caso exista, somamos as quantidades
      if(_listaItensMesa.length > 0)
      {
        String desc_item_atual = _itemLista.desc_item;
        String obs_item_atual = _itemLista.obs_adici;
        int indice_encontrado = -1;
        for(int i = 0; i < _listaItensMesa.length; i++)
        {
          for(int y = 0; y < _listaItensMesa.length; y++)
          {
            if(_listaItensMesa[y].desc_item == desc_item_atual && _listaItensMesa[y].obs_adici == obs_item_atual)
            {
              indice_encontrado = y;
            }
          }
          if(indice_encontrado != -1)
          {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
            ItemMesa _ja_existe = _listaItensMesa[indice_encontrado];
            num _novo_valor = _ja_existe.valor_tot + _itemLista.valor_tot;
            int _nova_qtd = _ja_existe.qtd + _itemLista.qtd;
            _ja_existe.valor_tot = _novo_valor;
            _ja_existe.qtd = _nova_qtd;
            _listaItensMesa[indice_encontrado] = _ja_existe;
            break;
          }
          else{
            _itemLista.id_item = _ult_id_registrado + 1;
            _ult_id_registrado = _itemLista.id_item;
            _listaItensMesa.add(_itemLista);
            break;
          }
        }
      }
      else
      {
        _itemLista.id_item = _ult_id_registrado + 1;
        _ult_id_registrado = _itemLista.id_item;
        _listaItensMesa.add(_itemLista);
      }
    }
    num _total_inserir_pedido = _calcula_total_inserir_mesa() + _taxa_pedido;
    _pedido_editar.total = _total_inserir_pedido;
    _reimprimir_pedido(_pedido_editar);
    //exclui a lista atual da mesa
    await FirebaseDatabase.instance.ref().child('itens-pedido').child(widget._identificador.toString()).remove();
    //carrega a nova lista
    final ref = FirebaseDatabase.instance.ref("itens-pedido/" + widget._identificador.toString());
    for(int i = 1; i <= _listaItensMesa.length; i++)
    {
      int _id_registrar = i;
      final json = _listaItensMesa[i-1].toJson();
      await ref.child(_id_registrar.toString()).set(json);
    }
    //salvar novo total do pedido
    if(_calcula_total_inserir_mesa() > 0)
    {
      final ref_pedido = FirebaseDatabase.instance.ref("pedidos/" + _pedido_editar.id_pedido.toString());
      await ref_pedido.child("total").set(_total_inserir_pedido);
    }
    else
    {
      await FirebaseDatabase.instance.ref().child('pedidos').child(_pedido_editar.id_pedido.toString()).remove();
      await FirebaseDatabase.instance.ref().child('itens-pedido').child(_pedido_editar.identificador.toString()).remove();
    }
    //retornamos a tela principal
    Navigator.of(context).pop();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Mesas()
        )
    );
  }

  num _calcula_total_inserir_mesa()
  {
    num _total_inserir_mesa = 0;
    for(ItemMesa it in _listaItensMesa)
    {
      _total_inserir_mesa = _total_inserir_mesa + it.valor_tot;
    }
    return _total_inserir_mesa;
  }
  mostrarDialogoSalvando()
  {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScaffoldMessenger(
        child: Builder(
            builder: (context) => WillPopScope(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Dialog(
                    elevation: 6,
                    insetAnimationDuration: Duration(seconds: 1),
                    insetAnimationCurve: Curves.slowMiddle,
                    insetPadding: EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), //this right here
                    child: Container(
                      //height: 300.0,
                      //width: 300.0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                              height: 50,
                              width: 300,
                              alignment: Alignment.center,
                              child: Text(
                                'Salvando itens e imprimindo na cozinha...',
                                style: TextStyle(color: CustomColors().corMarromSF),
                              )
                          ),
                          Container(
                              height: 50,
                              width: 300,
                              alignment: Alignment.center,
                              child: LinearProgressIndicator(
                                minHeight: 10,
                                backgroundColor: CustomColors().corLaranjaSF,
                                valueColor: AlwaysStoppedAnimation<Color> (CustomColors().corMarromSF),
                              )
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                onWillPop: () async => false
            )
        ),
      ),
    );
  }
  _reimprimir_pedido(Pedido reimprimir) async
  {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(widget._ip_impressora.toString(), port: 9100); //10.253.0.98 _parametros.ip_impressora.toString()

    if (res == PosPrintResult.success) {
      //verificar a qtd de vias para imprimir
      for(int i = 0; i < widget._qtd_vias_imprimir; i++)
      {
        if(reimprimir.tipo == 0)
          _reimprimir_pedido_balcao(printer, reimprimir);
        else
          _reimprimir_pedido_entrega(printer, reimprimir);
      }
      printer.disconnect();
    }

    print('Print result: ${res.msg}');
  }

  Future<void> _reimprimir_pedido_balcao(NetworkPrinter printer, Pedido dados_pedido) async {

    String data = dados_pedido.data.substring(11, 19);
    String forma_pag = "";

    if(dados_pedido.pagamento == 0)
      forma_pag = "DINHEIRO";
    if(dados_pedido.pagamento == 1)
      forma_pag = "CARTAO";
    if(dados_pedido.pagamento == 2)
      forma_pag = "PIX";
    //Cabeçalho da impressão
    printer.text("Retirada no Balcao",
        styles: PosStyles(
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.center
        ));
    printer.text("Hora: " + data,
        styles: PosStyles(
            align: PosAlign.center
        ));
    printer.text("----------------------------------------");
    printer.text(dados_pedido.nome_cliente, styles: PosStyles(bold: true,align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2));
    printer.text(dados_pedido.celular_cliente, styles: PosStyles(bold: true,align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2));
    printer.text("----------------------------------------");
    printer.row([
      PosColumn(
        text: 'QTD',
        width: 1,
        styles: PosStyles(align: PosAlign.left, underline: true, bold: true),
      ),
      PosColumn(
        text: 'ITEM',
        width: 11,
        styles: PosStyles(align: PosAlign.center, underline: true, bold: true),
      ),
    ]);
    String _linha1 = "";
    String _linha2 = "";
    int _parametro_num_char = 0;
    for(int i = 0; i < _listaItensMesa.length; i++)
    {
      _parametro_num_char = 0;
      String item_desc = _remove_diacritics(_listaItensMesa[i].desc_item);
      String item_mostrar = item_desc;
      if(item_desc.length > 19){
        _linha1 = item_desc.substring(0, 19);
        _linha2 = item_desc.substring(19, item_desc.length);
        _parametro_num_char = 1;

        printer.row([
          PosColumn(
            text: _listaItensMesa[i].qtd.toString(),
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
          PosColumn(
            text: _remove_diacritics(_linha1),
            //text: _remove_diacritics(_listaItensMesa[i].desc_item),
            width: 11,
            styles: PosStyles(align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
        ]);
      }
      else{
        printer.row([
          PosColumn(
            text: _listaItensMesa[i].qtd.toString(),
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
          PosColumn(
            text: item_mostrar,
            //text: _remove_diacritics(_listaItensMesa[i].desc_item),
            width: 11,
            styles: PosStyles(align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
        ]);
      }

      if(_parametro_num_char == 1)
      {
        printer.row([
          PosColumn(
            text: " ",
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: _remove_diacritics(_linha2),
            width: 11,
            styles: PosStyles(align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
        ]);
      }
      if(!_listaItensMesa[i].obs_adici.isEmpty && _listaItensMesa[i].obs_adici != "")
      {
        printer.row([
          PosColumn(
            text: "",
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: _remove_diacritics(_listaItensMesa[i].obs_adici).replaceAll("\n", ", "),
            width: 11,
            styles: PosStyles(align: PosAlign.left, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
        ]);
      }
      printer.text("----------------------------------------");
    }
    String _valor_mostrar = "";
    _valor_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(dados_pedido.total);
    printer.row([
      PosColumn(
          text: 'TOTAL',
          width: 4,
          styles: PosStyles(
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
      PosColumn(
          text: _valor_mostrar,
          width: 8,
          styles: PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
    ]);
    printer.text("Forma de Pagamento: " + forma_pag,
        styles: PosStyles(
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left
        ));
    printer.text("========================================");
    if(!dados_pedido.obs.isEmpty && dados_pedido.obs != "")
    {
      printer.text("Obs.: " + dados_pedido.obs.toString(),
          styles: PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              align: PosAlign.left,
              bold: true
          ));
      printer.text("----------------------------------------");
    }
    printer.text("Powered by SSoft",
        styles: PosStyles(
            align: PosAlign.center
        ));

    //VERIFICAR A QUANTIDADE DE VIAS PARA IMPRIMIR
    printer.feed(2);
    printer.cut();
  }

  Future<void> _reimprimir_pedido_entrega(NetworkPrinter printer, Pedido dados_pedido) async {

    String data = dados_pedido.data.substring(11, 19);
    String forma_pag = "";

    if(dados_pedido.pagamento == 0)
      forma_pag = "DINHEIRO";
    if(dados_pedido.pagamento == 1)
      forma_pag = "CARTAO";
    if(dados_pedido.pagamento == 2)
      forma_pag = "PIX";
    //Cabeçalho da impressão
    printer.text("Entrega",
        styles: PosStyles(
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.center
        ));
    printer.text("Hora: " + data,
        styles: PosStyles(
            align: PosAlign.center
        ));
    printer.text("----------------------------------------");
    printer.text(dados_pedido.nome_cliente, styles: PosStyles(bold: true,align: PosAlign.left));
    printer.text(dados_pedido.celular_cliente, styles: PosStyles(bold: true,align: PosAlign.left));
    printer.text(dados_pedido.endereco_cliente, styles: PosStyles(bold: true,align: PosAlign.left));
    printer.text("----------------------------------------");
    printer.row([
      PosColumn(
        text: 'QTD',
        width: 1,
        styles: PosStyles(align: PosAlign.left, underline: true, bold: true),
      ),
      PosColumn(
        text: 'ITEM',
        width: 11,
        styles: PosStyles(align: PosAlign.center, underline: true, bold: true),
      ),
    ]);
    String _linha1 = "";
    String _linha2 = "";
    int _parametro_num_char = 0;
    for(int i = 0; i < _listaItensMesa.length; i++)
    {
      _parametro_num_char = 0;
      String item_desc = _remove_diacritics(_listaItensMesa[i].desc_item);
      String item_mostrar = item_desc;
      if(item_desc.length > 19){
        _linha1 = item_desc.substring(0, 19);
        _linha2 = item_desc.substring(19, item_desc.length);
        _parametro_num_char = 1;

        printer.row([
          PosColumn(
            text: _listaItensMesa[i].qtd.toString(),
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
          PosColumn(
            text: _remove_diacritics(_linha1),
            //text: _remove_diacritics(_listaItensMesa[i].desc_item),
            width: 11,
            styles: PosStyles(align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
        ]);
      }
      else{
        printer.row([
          PosColumn(
            text: _listaItensMesa[i].qtd.toString(),
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
          PosColumn(
            text: item_mostrar,
            //text: _remove_diacritics(_listaItensMesa[i].desc_item),
            width: 11,
            styles: PosStyles(align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
        ]);
      }

      if(_parametro_num_char == 1)
      {
        printer.row([
          PosColumn(
            text: " ",
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: _remove_diacritics(_linha2),
            width: 11,
            styles: PosStyles(align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
        ]);
      }
      if(!_listaItensMesa[i].obs_adici.isEmpty && _listaItensMesa[i].obs_adici != "")
      {
        printer.row([
          PosColumn(
            text: "",
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: _remove_diacritics(_listaItensMesa[i].obs_adici).replaceAll("\n", ", "),
            width: 11,
            styles: PosStyles(align: PosAlign.left, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
        ]);
      }
      printer.text("----------------------------------------");
    }
    String _valor_mostrar = "";
    String _valor_taxa_mostrar = "";
    _valor_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(dados_pedido.total);
    _valor_taxa_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(_taxa_pedido);
    printer.text('Taxa:' + _valor_taxa_mostrar);
    printer.row([
      PosColumn(
          text: 'TOTAL',
          width: 4,
          styles: PosStyles(
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
      PosColumn(
          text: _valor_mostrar,
          width: 8,
          styles: PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
    ]);
    printer.text("Forma de Pagamento: " + forma_pag,
        styles: PosStyles(
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left
        ));
    printer.text("========================================");
    if(!dados_pedido.obs.isEmpty && dados_pedido.obs != "")
    {
      printer.text("Obs.: " + dados_pedido.obs.toString(),
          styles: PosStyles(
              height: PosTextSize.size1,
              width: PosTextSize.size1,
              align: PosAlign.left,
              bold: true
          ));
      printer.text("----------------------------------------");
    }
    printer.text("Powered by SSoft",
        styles: PosStyles(
            align: PosAlign.center
        ));

    //VERIFICAR A QUANTIDADE DE VIAS PARA IMPRIMIR
    printer.feed(2);
    printer.cut();
  }
  String _remove_diacritics(String str) {

    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }

    return str;

  }
}
