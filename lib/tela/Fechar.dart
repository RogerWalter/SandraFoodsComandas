import 'package:comandas_app/model/Comanda.dart';
import 'package:comandas_app/model/ItemComanda.dart';
import 'package:comandas_app/model/Mesa.dart';
import 'package:comandas_app/tela/Mesas.dart';
import 'package:comandas_app/model/Parametro.dart';
import 'package:comandas_app/res/CustomColors.dart';
import 'package:comandas_app/tela/Adicionar.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/ItemMesa.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Fechar(0, 0, "", 0, "")
  ));
}
class Fechar extends StatefulWidget {

  int _numMesa = 0;
  num _total_mesa = 0;
  String? _ip_impressora = "";
  int _qtd_imp = 1;
  String? _identificador_mesa = "";

  Fechar(this._numMesa, this._total_mesa, this._ip_impressora,this._qtd_imp, this._identificador_mesa);

  @override
  _FecharState createState() => _FecharState();
}
enum TipoPagamento {nul, din, car, pix}
class _FecharState extends State<Fechar> {

  Color _corLaranjaSF = const Color(0xffff6900);
  Color _corMarromSF = const Color(0xff3d2314);

  bool _visibilityProgress = true;
  bool _visibilityList = false;
  bool _visibilityFAB = true;

  int _tipo_fechamento = 0;// 0 = TOTAL | 1 = PARCIAL

  var _indices_selecionados = [];

  int _forma_de_pagamento = -1; //0 - DIN | 1 - CAR | 2 - PIX

  final List <ItemMesa> _listaItensMesa = [];
  List <ItemMesa> _listaItensMesaTotal = [];
  final List <ItemMesa> _listaItensMesaParcial = [];
  final List <ItemComanda> _listaItensMesaParcialRelatorio = [];
  final List <ItemComanda> _listaItensMesaTotalRelatorio = [];

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

            _listaItensMesa.add(_item_dividido);
          }
        }
        else{
          _listaItensMesa.add(_itemLista);
        }
      }
    }
    _listaItensMesaTotal = _listaItensMesa;
    setState(() {
      _indices_selecionados.clear();
      _visibilityList = true;
      _visibilityProgress = false;
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
          title: Text("Fechar Conta da Mesa " + widget._numMesa.toString(), style: TextStyle(color: Colors.white)),
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
                                    child: InkWell(
                                      onTap: (){
                                        setState(() {
                                          if(_indices_selecionados.contains(index))
                                          {
                                            _indices_selecionados.remove(index);
                                            _listaItensMesaParcial.remove(_listaItensMesa[index]);
                                            if(_listaItensMesaParcial.length == _listaItensMesaTotal.length)
                                              _visibilityFAB = false;
                                            else
                                              _visibilityFAB = true;
                                          }
                                          else
                                          {
                                            _indices_selecionados.add(index);
                                            _listaItensMesaParcial.add(_listaItensMesa[index]);
                                            if(_listaItensMesaParcial.length == _listaItensMesaTotal.length)
                                              _visibilityFAB = false;
                                            else
                                              _visibilityFAB = true;
                                          }
                                        });
                                      },
                                      child: ListTile(
                                        tileColor: _indices_selecionados.contains(index) ? Colors.green.withOpacity(0.15) : Colors.white,
                                        leading:  CircleAvatar(
                                          backgroundColor: _indices_selecionados.contains(index) ? Colors.green : _corLaranjaSF,
                                          child: _indices_selecionados.contains(index) ? Icon(Icons.check, color: Colors.white,) : Icon(Icons.forward, color: Colors.white,),
                                        ),
                                        title: Padding(
                                          padding: EdgeInsets.fromLTRB(0, 4, 0, 2),
                                          child: Text(
                                            (!_listaItensMesa[index].obs_adici.isEmpty && _listaItensMesa[index].obs_adici != "") ? (_listaItensMesa[index].desc_item + "\n(" + _listaItensMesa[index].obs_adici.replaceAll("\n", ", ") + ")") : _listaItensMesa[index].desc_item ,
                                            //_listaItensMesa[index].desc_item,
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
                                    )
                                );
                              },
                            ),
                        )
                    )
                  ),
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
                        if(_listaItensMesaParcial.length > 0) {
                          dialogo_fechar_conta_parcial();
                        }
                        else{
                          final snackBar = SnackBar(
                            backgroundColor: Colors.red,
                            content: Text(
                              'Nenhum item selecionado para fechamento parcial',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white
                              ),
                            ),
                            action: SnackBarAction(
                              label: 'Ok',
                              textColor: Colors.black,
                              onPressed: () {
                              },
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          return;
                        }
                      },
                      label: Column(
                        children: <Widget>[
                          const Text('Parcial', style: TextStyle(fontSize: 14)),
                          Text(NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_valor_parcial()), style: TextStyle(fontSize: 20))
                        ],
                      ),
                      icon: const Icon(Icons.note),
                      backgroundColor: Colors.amber,
                      splashColor: Colors.white,
                      heroTag: null,
                    ),
                  )
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    dialogo_fechar_conta_total();
                  },
                  label: Column(
                      children: <Widget>[
                      const Text('Total', style: TextStyle(fontSize: 14)),
                      Text(NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_valor_total()), style: TextStyle(fontSize: 20))
                      ],
                    ),
                  icon: const Icon(Icons.list_alt),
                  backgroundColor: Colors.green,
                  splashColor: Colors.white,
                  heroTag: null,
                ),
              )
            )
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  num _calcula_valor_parcial()
  {
    num _valor_parcial = 0;
    for(ItemMesa it in _listaItensMesaParcial)
    {
      _valor_parcial = _valor_parcial + it.valor_tot;
    }
    return _valor_parcial;
  }

  num _calcula_valor_total()
  {
    num _valor_total = 0;
    for(ItemMesa it in _listaItensMesa)
    {
      _valor_total = _valor_total + it.valor_tot;
    }
    return _valor_total;
  }

  dialogo_fechar_conta_parcial()
  {
    TipoPagamento? _opcao = TipoPagamento.nul;
    int _tipo_pagamento = -1;
    //recuperamos o parcial
    num _valor_parcial = _calcula_valor_parcial();
    //mostramos em tela
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
                      child: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState){
                          return Container(
                              width: 300,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                                    child: Text(
                                      'Pagamento Parcial: Mesa  ' + widget._numMesa.toString(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16, color: CustomColors().corMarromSF, fontWeight: FontWeight.bold),),
                                  ),
                                  Text('\n'+ NumberFormat.simpleCurrency(locale: 'pt_BR').format(_valor_parcial), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.w700),),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(0, 16, 0, 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Row(
                                          //mainAxisAlignment: MainAxisAlignment.center,
                                          children: <Widget>[
                                            Radio<TipoPagamento>(
                                              value: TipoPagamento.din,
                                              activeColor: CustomColors().corLaranjaSF,
                                              groupValue: _opcao,
                                              onChanged: (TipoPagamento? value) {
                                                setState(() {
                                                  _opcao = value;
                                                  _forma_de_pagamento = 0;
                                                });
                                              },
                                            ),
                                            const Text('Dinheiro', style: TextStyle(color: const Color(0xff3d2314)),),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: <Widget>[
                                            Radio<TipoPagamento>(
                                              value: TipoPagamento.car,
                                              groupValue: _opcao,
                                              activeColor: CustomColors().corLaranjaSF,
                                              onChanged: (TipoPagamento? value) {
                                                setState(() {
                                                  _opcao = value;
                                                  _forma_de_pagamento = 1;
                                                });
                                              },
                                            ),
                                            const Text('Cartão', style: TextStyle(color: const Color(0xff3d2314))),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: <Widget>[
                                            Radio<TipoPagamento>(
                                              value: TipoPagamento.pix,
                                              groupValue: _opcao,
                                              activeColor: CustomColors().corLaranjaSF,
                                              onChanged: (TipoPagamento? value) {
                                                setState(() {
                                                  _opcao = value;
                                                  _forma_de_pagamento = 2;
                                                });
                                              },
                                            ),
                                            const Text('Pix', style: TextStyle(color: const Color(0xff3d2314))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      TextButton(
                                          onPressed: () {
                                            if(_forma_de_pagamento != -1)
                                            {
                                              Navigator.of(context).pop();
                                              _fechar_conta_parcial(_valor_parcial, _forma_de_pagamento);
                                            }
                                            else
                                            {
                                              final snackBar = SnackBar(
                                                backgroundColor: Colors.red,
                                                content: Text(
                                                  'Informe um tipo de pagamento',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      color: Colors.white
                                                  ),
                                                ),
                                                action: SnackBarAction(
                                                  label: 'Ok',
                                                  textColor: Colors.black,
                                                  onPressed: () {
                                                  },
                                                ),
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                              return;
                                            }
                                          },
                                          child: const Text(
                                              'Confirmar',
                                              style: TextStyle(fontSize: 16, color: const Color(0xffff6900), fontWeight: FontWeight.bold)
                                          )
                                      ),
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text(
                                              'Sair',
                                              style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold)
                                          )
                                      )
                                    ],
                                  )
                                ],
                              )
                          );
                        },
                      )
                  ),
                ),
                onWillPop: () async => false
            )
        ),
      ),
    );
  }

  dialogo_fechar_conta_total()
  {
    TipoPagamento? _opcao = TipoPagamento.nul;
    int _tipo_pagamento = -1;
    //recuperamos o parcial
    num _valor_total = _calcula_valor_total();
    //mostramos em tela
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
                    child: StatefulBuilder(
                      builder: (BuildContext context, StateSetter setState){
                        return Container(
                          width: 300,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Padding(
                                    padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                                  child: Text(
                                    'Pagamento Total: Mesa  ' + widget._numMesa.toString(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: CustomColors().corMarromSF, fontWeight: FontWeight.bold),),
                                ),
                                Text('\n'+ NumberFormat.simpleCurrency(locale: 'pt_BR').format(_valor_total), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.w700),),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(0, 16, 0, 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Row(
                                        //mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Radio<TipoPagamento>(
                                            value: TipoPagamento.din,
                                            activeColor: CustomColors().corLaranjaSF,
                                            groupValue: _opcao,
                                            onChanged: (TipoPagamento? value) {
                                              setState(() {
                                                _opcao = value;
                                                _forma_de_pagamento = 0;
                                              });
                                            },
                                          ),
                                          const Text('Dinheiro', style: TextStyle(color: const Color(0xff3d2314)),),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Radio<TipoPagamento>(
                                            value: TipoPagamento.car,
                                            groupValue: _opcao,
                                            activeColor: CustomColors().corLaranjaSF,
                                            onChanged: (TipoPagamento? value) {
                                              setState(() {
                                                _opcao = value;
                                                _forma_de_pagamento = 1;
                                              });
                                            },
                                          ),
                                          const Text('Cartão', style: TextStyle(color: const Color(0xff3d2314))),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Radio<TipoPagamento>(
                                            value: TipoPagamento.pix,
                                            groupValue: _opcao,
                                            activeColor: CustomColors().corLaranjaSF,
                                            onChanged: (TipoPagamento? value) {
                                              setState(() {
                                                _opcao = value;
                                                _forma_de_pagamento = 2;
                                              });
                                            },
                                          ),
                                          const Text('Pix', style: TextStyle(color: const Color(0xff3d2314))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    TextButton(
                                        onPressed: () {
                                          if(_forma_de_pagamento != -1)
                                          {
                                            Navigator.of(context).pop();
                                            _fechar_conta_total(_valor_total, _forma_de_pagamento);
                                          }
                                          else
                                          {
                                            final snackBar = SnackBar(
                                              backgroundColor: Colors.red,
                                              content: Text(
                                                'Informe um tipo de pagamento',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: Colors.white
                                                ),
                                              ),
                                              action: SnackBarAction(
                                                label: 'Ok',
                                                textColor: Colors.black,
                                                onPressed: () {
                                                },
                                              ),
                                            );
                                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                            return;
                                          }
                                        },
                                        child: const Text(
                                            'Confirmar',
                                            style: TextStyle(fontSize: 16, color: const Color(0xffff6900), fontWeight: FontWeight.bold)
                                        )
                                    ),
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text(
                                            'Sair',
                                            style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold)
                                        )
                                    )
                                  ],
                                )
                              ],
                            )
                        );
                      },
                    )
                  ),
                ),
                onWillPop: () async => false
            )
        ),
      ),
    );
  }

  _fechar_conta_parcial(num _valor_parcial, int _tipo_pagamento_dialogo) async
  {
    setState(() {
      _visibilityList = false;
      _visibilityProgress = true;
    });
    //imprimimos a conta parcial
    _tipo_fechamento = 1;
    _imprimir_conta();
    //removemos os itens da lista que possui todos os itens da mesa
    for(ItemMesa it in _listaItensMesaParcial)
    {
      _listaItensMesaTotal.remove(it);
    }
    //limpar itens da mesa para atualizar na sequencia
    await FirebaseDatabase.instance.ref().child('itens-mesa').child(widget._numMesa.toString()).remove();
    //registramos os itens na mesa
    final ref = FirebaseDatabase.instance.ref("itens-mesa/" + widget._numMesa.toString());
    for(int i = 1; i <= _listaItensMesaTotal.length; i++)
    {
      int _id_registrar = i;
      final json = _listaItensMesaTotal[i-1].toJson();
      await ref.child(_id_registrar.toString()).set(json);
    }
    //reduzimos este pagamento parcial do total da mesa
    num _novo_total_mesa = widget._total_mesa - _valor_parcial;
    final ref_mesa = FirebaseDatabase.instance.ref("mesas/" + widget._numMesa.toString()).child("total");
    await ref_mesa.set(_novo_total_mesa);
    //salvamos esse pagamento para os relatórios do sistema
    DateTime now = DateTime.now();
    String data = DateFormat('dd-MM-yyyy kk:mm:ss').format(now);
    String id_registro = "P-" + widget._identificador_mesa.toString();
    Comanda _pagamento_salvar = Comanda();
    _pagamento_salvar.id = id_registro;
    _pagamento_salvar.total = _valor_parcial;
    _pagamento_salvar.mesa = widget._numMesa;
    _pagamento_salvar.data = data;
    _pagamento_salvar.pagamento = _tipo_pagamento_dialogo;
    _pagamento_salvar.fechamento = 0;
    for(int i = 1; i <= _listaItensMesaParcial.length; i++)
    {
      //VAMOS UNIR O QUE FOR REPETIDO, PARA SALVAR NA SEQUENCIA
      if(_listaItensMesaParcialRelatorio.length > 0)
      {
        ItemComanda item = ItemComanda();
        if(_listaItensMesaParcialRelatorio.firstWhere((it) => it.nome == _listaItensMesaParcial[i-1].desc_item, orElse: () => item) != item)
        {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
          ItemComanda _ja_existe = _listaItensMesaParcialRelatorio.firstWhere((it) => it.nome == _listaItensMesaParcial[i-1].desc_item);
          int _indice = _listaItensMesaParcialRelatorio.indexOf(_ja_existe);
          num _novo_valor = _ja_existe.valor + _listaItensMesaParcial[i-1].valor_tot;
          int _nova_qtd = _ja_existe.qtd + _listaItensMesaParcial[i-1].qtd;
          _ja_existe.valor = _novo_valor;
          _ja_existe.qtd = _nova_qtd;
          _listaItensMesaParcialRelatorio[_indice] = _ja_existe;
        }
        else{
          ItemComanda _item_salvar = ItemComanda();
          _item_salvar.id = id_registro;//id_registro;
          _item_salvar.mesa = widget._numMesa;
          _item_salvar.data = data;
          _item_salvar.nome = _listaItensMesaParcial[i-1].desc_item;
          _item_salvar.valor = _listaItensMesaParcial[i-1].valor_tot;
          _item_salvar.qtd = _listaItensMesaParcial [i-1].qtd;
          _listaItensMesaParcialRelatorio.add(_item_salvar);
        }
      }
      else{
        ItemComanda _item_salvar = ItemComanda();
        _item_salvar.id = id_registro;//id_registro;
        _item_salvar.mesa = widget._numMesa;
        _item_salvar.data = data;
        _item_salvar.nome = _listaItensMesaParcial[i-1].desc_item;
        _item_salvar.valor = _listaItensMesaParcial[i-1].valor_tot;
        _item_salvar.qtd = _listaItensMesaParcial [i-1].qtd;
        _listaItensMesaParcialRelatorio.add(_item_salvar);
      }
    }
    for(int i = 1; i <= _listaItensMesaParcialRelatorio.length; i++)
    {
      final json0 = _listaItensMesaParcialRelatorio[i-1].toJson();
      String chave_firebase = i.toString() + "_" + _listaItensMesaParcialRelatorio[i-1].id;
      final ref_comanda_item = FirebaseDatabase.instance.ref("fechado-itens/" + chave_firebase);
      await ref_comanda_item.set(json0);
    }

    final json1 = _pagamento_salvar.toJson();
    final ref_comanda = FirebaseDatabase.instance.ref('fechado/' + id_registro);
    await ref_comanda.set(json1);
    //atualizamos a tela
    _listaItensMesaParcial.clear();
    _indices_selecionados.clear();
    _recuperar_itens_mesa();
  }

  _fechar_conta_total(num _valor_total, int _tipo_pagamento_dialogo) async
  {
    setState(() {
      _visibilityList = false;
      _visibilityProgress = true;
    });
    //imprimimos a conta total
    _tipo_fechamento = 0;
    _imprimir_conta();
    //salvamos esse pagamento para os relatórios do sistema
    DateTime now = DateTime.now();
    String data = DateFormat('dd-MM-yyyy kk:mm:ss').format(now);
    String id_registro = "T-" + widget._identificador_mesa.toString();
    Comanda _pagamento_salvar = Comanda();
    _pagamento_salvar.id = id_registro;
    _pagamento_salvar.total = _valor_total;
    _pagamento_salvar.mesa = widget._numMesa;
    _pagamento_salvar.data = data;
    _pagamento_salvar.pagamento = _tipo_pagamento_dialogo;
    _pagamento_salvar.fechamento = 1;
    for(int i = 1; i <= _listaItensMesaTotal.length; i++)
    {
      if(_listaItensMesaTotalRelatorio.length > 0)
      {
        ItemComanda item = ItemComanda();
        if(_listaItensMesaTotalRelatorio.firstWhere((it) => it.nome == _listaItensMesaTotal[i-1].desc_item, orElse: () => item) != item)
        {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
          ItemComanda _ja_existe = _listaItensMesaTotalRelatorio.firstWhere((it) => it.nome == _listaItensMesaTotal[i-1].desc_item);
          int _indice = _listaItensMesaTotalRelatorio.indexOf(_ja_existe);
          num _novo_valor = _ja_existe.valor + _listaItensMesaTotal[i-1].valor_tot;
          int _nova_qtd = _ja_existe.qtd + _listaItensMesaTotal[i-1].qtd;
          _ja_existe.valor = _novo_valor;
          _ja_existe.qtd = _nova_qtd;
          _listaItensMesaTotalRelatorio[_indice] = _ja_existe;
        }
        else{
          ItemComanda _item_salvar = ItemComanda();
          _item_salvar.id = id_registro;//id_registro;
          _item_salvar.mesa = widget._numMesa;
          _item_salvar.data = data;
          _item_salvar.nome = _listaItensMesaTotal[i-1].desc_item;
          _item_salvar.valor = _listaItensMesaTotal[i-1].valor_tot;
          _item_salvar.qtd = _listaItensMesaTotal [i-1].qtd;
          _listaItensMesaTotalRelatorio.add(_item_salvar);
        }
      }
      else{
        ItemComanda _item_salvar = ItemComanda();
        _item_salvar.id = id_registro;//id_registro;
        _item_salvar.mesa = widget._numMesa;
        _item_salvar.data = data;
        _item_salvar.nome = _listaItensMesaTotal[i-1].desc_item;
        _item_salvar.valor = _listaItensMesaTotal[i-1].valor_tot;
        _item_salvar.qtd = _listaItensMesaTotal [i-1].qtd;
        _listaItensMesaTotalRelatorio.add(_item_salvar);
      }
    }
    for(int i = 1; i <= _listaItensMesaTotalRelatorio.length; i++)
    {
      final json0 = _listaItensMesaTotalRelatorio[i-1].toJson();
      String chave_firebase = i.toString() + "_" + _listaItensMesaTotalRelatorio[i-1].id;
      final ref_comanda_item = FirebaseDatabase.instance.ref("fechado-itens/" + chave_firebase);
      await ref_comanda_item.set(json0);
    }
    final json1 = _pagamento_salvar.toJson();
    final ref_comanda = FirebaseDatabase.instance.ref('fechado/' + id_registro);
    await ref_comanda.set(json1);
    //limpar itens da mesa
    await FirebaseDatabase.instance.ref().child('itens-mesa').child(widget._numMesa.toString()).remove();
    //fechamos a mesa e a liberamos alterando seu status
    Mesa _mesa = Mesa();
    _mesa.total = 0;
    _mesa.status = 0;
    _mesa.numero = widget._numMesa;
    final json = _mesa.toJson();
    final ref_mesa = FirebaseDatabase.instance.ref("mesas/" + widget._numMesa.toString());
    await ref_mesa.set(json);
    //não há mais itens. Fechamos a tela.
    Navigator.of(context).pop();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Mesas()
        )
    );
  }

  _imprimir_conta() async
  {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(widget._ip_impressora.toString(), port: 9100);

    if (res == PosPrintResult.success) {
      //verificar a qtd de vias para imprimir
      for(int i = 0; i < widget._qtd_imp; i++)
      {
        _gerar_impressao(printer);
      }
      printer.disconnect();
    }

    print('Print result: ${res.msg}');
  }

  Future<void> _gerar_impressao(NetworkPrinter printer) async {

    DateTime now = DateTime.now();
    String data = DateFormat('kk:mm:ss').format(now);
    String forma_pag = "";

    if(_forma_de_pagamento == 0)
      forma_pag = "DINHEIRO";
    if(_forma_de_pagamento == 1)
      forma_pag = "CARTAO";
    if(_forma_de_pagamento == 2)
      forma_pag = "PIX";
    //Cabeçalho da impressão
    printer.text("Conta da Mesa " + widget._numMesa.toString(),
        styles: PosStyles(
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.center
        ));
    String _titulo = "";
    if(_tipo_fechamento == 0)
        _titulo = "Pagamento Total";
    else
      _titulo = "Pagamento Parcial";
    printer.text(_titulo,
        styles: PosStyles(
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.center
        ));
    printer.text("Hora: " + data,
        styles: PosStyles(
            align: PosAlign.center
        ));
    printer.text("----------------------------------------");
    printer.row([
      PosColumn(
        text: 'QTD',
        width: 1,
        styles: PosStyles(align: PosAlign.left, underline: true, bold: true),
      ),
      PosColumn(
        text: 'ITEM',
        width: 8,
        styles: PosStyles(align: PosAlign.left, underline: true, bold: true),
      ),
      PosColumn(
        text: 'VALOR',
        width: 3,
        styles: PosStyles(align: PosAlign.right, underline: true, bold: true),
      ),
    ]);
    if(_tipo_fechamento == 0){
      for(int i = 0; i < _listaItensMesaTotal.length; i++)
      {
        printer.row([
          PosColumn(
            text: _listaItensMesaTotal[i].qtd.toString(),
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: _remove_diacritics(_listaItensMesaTotal[i].desc_item),
            width: 8,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaItensMesaTotal[i].valor_tot),
            width: 3,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
        if(!_listaItensMesaTotal[i].obs_adici.isEmpty && _listaItensMesaTotal[i].obs_adici != "")
        {
          printer.row([
            PosColumn(
              text: "",
              width: 1,
              styles: PosStyles(align: PosAlign.left, bold: true),
            ),
            PosColumn(
              text: _remove_diacritics(_listaItensMesaTotal[i].obs_adici).replaceAll("\n", ", "),
              width: 8,
              styles: PosStyles(align: PosAlign.left, bold: true),
            ),
            PosColumn(
              text: "",
              width: 3,
              styles: PosStyles(align: PosAlign.left),
            ),
          ]);
        }
      }
    }
    else{
      for(int i = 0; i < _listaItensMesaParcial.length; i++)
      {
        printer.row([
          PosColumn(
            text: _listaItensMesaParcial[i].qtd.toString(),
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: _remove_diacritics(_listaItensMesaParcial[i].desc_item),
            width: 8,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaItensMesaParcial[i].valor_tot),
            width: 3,
            styles: PosStyles(align: PosAlign.right),
          ),
        ]);
        if(!_listaItensMesaParcial[i].obs_adici.isEmpty && _listaItensMesaParcial[i].obs_adici != "")
        {
          printer.row([
            PosColumn(
              text: "",
              width: 1,
              styles: PosStyles(align: PosAlign.left, bold: true),
            ),
            PosColumn(
              text: _remove_diacritics(_listaItensMesaParcial[i].obs_adici).replaceAll("\n", ", "),
              width: 8,
              styles: PosStyles(align: PosAlign.left, bold: true),
            ),
            PosColumn(
              text: "",
              width: 3,
              styles: PosStyles(align: PosAlign.left),
            ),
          ]);
        }
      }
    }
    printer.text("----------------------------------------");
    String _valor_mostrar = "";
    if(_tipo_fechamento == 0) {
      _valor_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_valor_total());
      }
    else{
      _valor_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_valor_parcial());
    }
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
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left
        ));
    printer.text("========================================");
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