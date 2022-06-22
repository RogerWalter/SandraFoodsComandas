import 'dart:typed_data';
import 'package:comandas_app/model/ItemCardapio.dart';
import 'package:comandas_app/model/ItemMesa.dart';
import 'package:comandas_app/model/Pedido.dart';
import 'package:comandas_app/model/Mesa.dart';
import 'package:comandas_app/model/Taxa.dart';
import 'package:comandas_app/model/Entrega.dart';
import 'package:comandas_app/model/Comanda.dart';
import 'package:comandas_app/model/ItemComanda.dart';
import 'package:comandas_app/model/Parametro.dart';
import 'package:comandas_app/res/CustomColors.dart';
import 'package:comandas_app/tela/Mesas.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:auto_size_text_pk/auto_size_text_pk.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Adicionar(0, "", "", 1, -1, "")
  ));
}
class Adicionar extends StatefulWidget {

  int _numMesa = 0;
  int _qtd_vias = 1;
  String? _garcom = "";
  String? _ip_imp = "";
  int _parametro_tipo_adicionar = -1; //0 = MESA | 1 = ENTREGA | 2 = BALCÃO | 3 = ENTREGA (editar)  | 4 = BALCÃO (editar)
  String? _identificador_pedido = "";

  Adicionar(this._numMesa, this._garcom, this._ip_imp, this._qtd_vias, this._parametro_tipo_adicionar, this._identificador_pedido);

  @override
  _AdicionarState createState() => _AdicionarState();

}
enum TipoPagamento {nul, din, car, pix}
class _AdicionarState extends State<Adicionar> {

  String? _nome_garcom = "";
  String _titulo_tela = "";

  bool _visibilityCard = false;
  bool _visibilityProgress = true;
  bool _visibilityList = false;
  bool _visibilitySemItens = false;

  TextEditingController _controllerDescricao = TextEditingController();
  TextEditingController _controllerObs1 = TextEditingController();
  TextEditingController _controllerObs2 = TextEditingController();
  TextEditingController _controllerObs3 = TextEditingController();
  TextEditingController _controllerAdicional = TextEditingController();
  TextEditingController _controllerQtd = TextEditingController();
  TextEditingController _controllerDesconto = TextEditingController();
  TextEditingController _controllerObsCozinha = TextEditingController();
  FocusNode _focusNodeDesc = FocusNode();
  FocusNode _focusNodeObs1 = FocusNode();
  FocusNode _focusNodeObs2 = FocusNode();
  FocusNode _focusNodeObs3 = FocusNode();
  FocusNode _focusNodeAdic = FocusNode();
  FocusNode _focusNodeDsct = FocusNode();
  FocusNode _focusNodeQtd = FocusNode();
  GlobalKey _descKey = GlobalKey();
  GlobalKey _obs1Key = GlobalKey();
  GlobalKey _obs2Key = GlobalKey();
  GlobalKey _obs3Key = GlobalKey();

  CustomColors cores = CustomColors();

  final List <ItemMesa> _listaItensMesa = [];
  final List <ItemMesa> _listaItensExistentesPedido= [];
  final List <Pedido> _listaPedidos = [];
  final List <ItemComanda> _listaItensMesaTotalRelatorio = [];
  final List <ItemMesa> _listaItensExistentesMesa = [];
  final List <ItemCardapio> _listaItens = [];
  final List <ItemCardapio> _listaAdicionais = [];
  List <ItemCardapio> _listaAdicionaisFiltrada = []; //lista que contém adicionais de itens específicos após a seleção do item

  ItemCardapio _item_selecionado = ItemCardapio();
  ItemCardapio _adicional_selecionado = ItemCardapio();
  num _total_item = 0;
  num _valor_adic = 0;
  num _valor_dsct = 0;
  num _valor_adic1 = 0;
  num _valor_adic2 = 0;
  num _valor_adic3 = 0;
  num _total_item_vezes_qtd = 0;
  String _adicionais_final = "";
  String _valor_total_mostrar = "R\$ 0,00";
  String _obs_cozinha = "";
  bool _cb_imprimir = true;
  int _param_imprimir = 0; //0 - SIM | 1 - NÃO

  int _indice_deletar = 0;

  int _parametro_tipo_visualizacao = 0; //0 - CARD | 1 - LISTA | ALTERADO SEMPRE QUE É SELECIONADO OUTRA OPÇÃO NAS CONFIGURAÇÕES

  //BALCÃO
  TextEditingController _ctlNomeBalc = TextEditingController();
  TextEditingController _ctlCeluBalc = TextEditingController();
  String _blc_nome_cli = "";
  String _blc_celu_cli = "";

  //ENTREGA
  num _taxa_atualizar_pedido = 0;
  final List <Taxa> _listaTaxas = [];
  Taxa _taxa_selecionada = Taxa();
  num _valor_taxa = 0;
  TipoPagamento? _opcao = TipoPagamento.nul;
  int _tipo_pagamento = -1;
  GlobalKey _bairroKey = GlobalKey();
  FocusNode _focusNodeBairro = FocusNode();
  TextEditingController _ctlNome = TextEditingController();
  TextEditingController _ctlCelular = TextEditingController();
  TextEditingController _ctlRua = TextEditingController();
  TextEditingController _ctlNumero = TextEditingController();
  TextEditingController _ctlBairro = TextEditingController();
  TextEditingController _ctlRef = TextEditingController();
  String _ent_nome_cli = "";
  String _ent_celu_cli = "";
  String _ent_rua_cli = "";
  String _ent_nume_cli = "";
  String _ent_bair_cli = "";
  String _ent_refe_cli = "";
  var mascaraCelular = new MaskTextInputFormatter(
      mask: '(##)#####-####',
      filter: { "#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy
  );

  _recuperarItens() async{
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("itens").get();
    if (snapshot.exists) {
      final json = snapshot.value as Map<dynamic, dynamic>;
      for(DataSnapshot ds in snapshot.children)
        {
          ItemCardapio _itemLista = ItemCardapio();
          final json = ds.value as Map<dynamic, dynamic>;
          _itemLista = ItemCardapio.fromJson(json);
          if(_itemLista.grupo != 0)
            _listaItens.add(_itemLista);
          else
            _listaAdicionais.add(_itemLista);
        }
      print("lista completa");
    }
  }
  _recuperarTaxas() async{
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("taxa").get();
    if (snapshot.exists) {
      final json = snapshot.value as Map<dynamic, dynamic>;
      for(DataSnapshot ds in snapshot.children)
      {
        Taxa _taxa = Taxa();
        final json = ds.value as Map<dynamic, dynamic>;
        _taxa = Taxa.fromJson(json);
        _listaTaxas.add(_taxa);
      }
      print("lista completa");
    }
  }
  _recuperarPedidos() async{
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("pedidos").get();
    if (snapshot.exists) {
      for(DataSnapshot ds in snapshot.children)
      {
        Pedido _itemLista = Pedido();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = Pedido.fromJson(json);
        _listaPedidos.add(_itemLista);
      }
    }
  }
  _recuperar_itens_pedido(String _identificador) async{
    _listaItensExistentesPedido.clear();
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("itens-pedido/" + _identificador.toString()).get();
    if (snapshot.exists) {
      final json = snapshot.value as List;
      for(DataSnapshot ds in snapshot.children)
      {
        ItemMesa _itemLista = ItemMesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = ItemMesa.fromJson(json);
        _listaItensExistentesPedido.add(_itemLista);
      }
    }
  }
  _limpar_dialogo() {
    _item_selecionado = ItemCardapio();
    _adicional_selecionado = ItemCardapio();
    _controllerDescricao.clear();
    _focusNodeDesc.requestFocus();
    _controllerDescricao.text = "";
    _controllerAdicional.text = "";
    _controllerDesconto.text = "";
    _controllerObs1.text = "";
    _controllerObs2.text = "";
    _controllerObs3.text = "";
    _controllerQtd.text = "";
    _valor_adic = 0;
    _valor_dsct = 0;
    _total_item = 0;
    _valor_total_mostrar = "R\$ 0,00";
    _listaAdicionaisFiltrada.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    if(widget._parametro_tipo_adicionar == 0)
      _titulo_tela = "Adicionar Itens à Mesa " + widget._numMesa.toString();
    if(widget._parametro_tipo_adicionar == 1){
      _titulo_tela = "Itens para Entrega";
      _recuperarTaxas();}
    if(widget._parametro_tipo_adicionar == 2)
      _titulo_tela = "Itens para Balcão";
    if(widget._parametro_tipo_adicionar == 3){
      _titulo_tela = "Atualizar Itens Entrega";
      _recuperar_itens_pedido(widget._identificador_pedido.toString());
    }
    if(widget._parametro_tipo_adicionar == 4){
      _titulo_tela = "Atualizar Itens Balcão";
      _recuperar_itens_pedido(widget._identificador_pedido.toString());
    }

    _listaItensMesa.clear();
    _recuperarItens();
    _recuperarPedidos();
    _recupera_itens_mesa();
    _recupera_itens_mesa_existentes();
    _focusNodeDesc.requestFocus();
    _criar_listener_valor_adic();
    _criar_listener_valor_dsct();
    /*Future.delayed(Duration.zero, () {
      this._imprimir_pedido();
    });*/
  }

  static String _displayStringForOption(ItemCardapio option) => option.nome;
  static String _displayStringForOptionBairro(Taxa option) => option.bairro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: CustomColors().corMarromSF,
        title: Text(_titulo_tela, style: TextStyle(color: Colors.white)),
        actions:[
          PopupMenuButton(
              icon: Icon(Icons.list, color: cores.corLaranjaSF,),
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
                padding:  EdgeInsets.fromLTRB(4,8,4,4),
                child: InputDecorator(
                    decoration: InputDecoration(
                      counterText: "",
                      contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                      labelText: "Item",
                      labelStyle: TextStyle(color: cores.corLaranjaSF, fontWeight: FontWeight.w700),
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        onPressed: (){_limpar_dialogo();},
                        icon: Icon(Icons.clear_rounded, color: Colors.black45,),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(width: 2, color: const Color(0xffff6900)),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(width: 2, color: const Color(0xffff6900)),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: RawAutocomplete<ItemCardapio>(
                      key: _descKey,
                      focusNode: _focusNodeDesc,
                      textEditingController: _controllerDescricao,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        return _listaItens.where((ItemCardapio option) => option.nome.toLowerCase()
                            .contains(textEditingValue.text.toLowerCase())
                        ).toList();
                      },
                      displayStringForOption: _displayStringForOption,
                      fieldViewBuilder: (BuildContext context,
                          TextEditingController textEditingController,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted) {
                        return TextFormField(
                          textCapitalization: TextCapitalization.characters,
                          controller: textEditingController,
                          focusNode: focusNode,
                          onFieldSubmitted: (String value) {
                            onFieldSubmitted();
                          },
                          style: TextStyle(fontWeight: FontWeight.w900),
                          cursorColor: cores.corLaranjaSF,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                          ),
                        );
                      },
                      optionsViewBuilder: (BuildContext context,
                          AutocompleteOnSelected<ItemCardapio> onSelected, Iterable<ItemCardapio> options) {
                        return Container(
                          color: Colors.transparent,
                            width: 300,
                            height: 350,
                          child: Scaffold(
                              backgroundColor: Colors.transparent,
                              body: Container(
                                color: Colors.white,
                                width: 300,
                                height: 350,
                                child: Container(
                                  color: cores.corLaranjaSF.withOpacity(0.10),
                                  width: 300,
                                  height: 350,
                                  child: ListView(
                                    shrinkWrap: true,
                                    children: options
                                        .map((ItemCardapio option) => GestureDetector(
                                      onTap: () {
                                        onSelected(option);
                                        _item_selecionado = option;
                                        _total_item = _item_selecionado.valor;
                                        final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
                                        String formatado = currencyFormatter.format(_total_item);
                                        _carrega_adicionais();
                                        setState(() {
                                          _valor_total_mostrar = formatado;
                                          _controllerQtd.text = "1";
                                          _controllerQtd.selection = TextSelection(
                                            baseOffset: 0,
                                            extentOffset: _controllerQtd.text.length,
                                          );
                                          _focusNodeQtd.requestFocus();
                                        });
                                      },
                                      child: ListTile(
                                        title: Text(option.nome),
                                        tileColor: Colors.transparent,
                                      ),
                                    ))
                                        .toList(),
                                  ),
                                )
                              )
                          )
                        );
                      },
                    )
                )
            ),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                        padding:  EdgeInsets.all(4),
                        child: Align(
                            child: Container(
                                child: InputDecorator(
                                    decoration: InputDecoration(
                                      counterText: "",
                                      contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                      labelText: "Adic - 1",
                                      labelStyle: TextStyle(color: cores.corMarromSF, fontWeight: FontWeight.w700),
                                      fillColor: Colors.white,
                                      hoverColor: cores.corMarromSF,
                                      focusColor: cores.corMarromSF,
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: RawAutocomplete<ItemCardapio>(
                                      key: _obs1Key,
                                      focusNode: _focusNodeObs1,
                                      textEditingController: _controllerObs1,
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        return _listaAdicionaisFiltrada.where((ItemCardapio option) => option.nome.toLowerCase()
                                            .contains(textEditingValue.text.toLowerCase())
                                        ).toList();
                                      },
                                      displayStringForOption: _displayStringForOption,
                                      fieldViewBuilder: (BuildContext context,
                                          TextEditingController textEditingController,
                                          FocusNode focusNode,
                                          VoidCallback onFieldSubmitted) {
                                        return TextFormField(
                                          onTap: (){
                                            if(!_controllerObs1.text.isEmpty)
                                            {
                                              _controllerObs1.clear();
                                              _valor_adic = _valor_adic - _valor_adic1;
                                              final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
                                              String valorAdicFormatado = currencyFormatter.format(_valor_adic);
                                              setState(() {
                                                _controllerAdicional.text = valorAdicFormatado.toString();
                                                FocusScope.of(context).unfocus();
                                              });

                                            }
                                          },
                                          textCapitalization: TextCapitalization.characters,
                                          controller: textEditingController,
                                          textInputAction: TextInputAction.none,
                                          focusNode: focusNode,
                                          onFieldSubmitted: (String value) {
                                            onFieldSubmitted();
                                          },
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                          cursorColor: cores.corMarromSF,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                          ),
                                        );
                                      },
                                      optionsViewBuilder: (BuildContext context,
                                          AutocompleteOnSelected<ItemCardapio> onSelected, Iterable<ItemCardapio> options) {
                                        return Container(
                                          color: Colors.transparent,
                                          width: 300,
                                          height: 350,
                                          child: Scaffold(
                                            backgroundColor: Colors.transparent,
                                            body: Container(
                                              color: Colors.white,
                                              width: 300,
                                              height: 350,
                                              child: Container(
                                                color: cores.corLaranjaSF.withOpacity(0.10),
                                                width: 300,
                                                height: 350,
                                                child: ListView(
                                                  children: options
                                                      .map((ItemCardapio option) => GestureDetector(
                                                    onTap: () {
                                                      onSelected(option);
                                                      _adicional_selecionado = option;
                                                      _valor_adic1 = _adicional_selecionado.valor;
                                                      _valor_adic = _adicional_selecionado.valor + _valor_adic;
                                                      final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
                                                      String valorAdicFormatado = currencyFormatter.format(_valor_adic);
                                                      _total_item = _item_selecionado.valor + _valor_adic;
                                                      String valorTotalItemFormatado = currencyFormatter.format(_total_item);
                                                      setState(() {
                                                        _controllerAdicional.text = valorAdicFormatado.toString();
                                                        _valor_total_mostrar = valorTotalItemFormatado.toString();
                                                        FocusScope.of(context).unfocus();
                                                      });
                                                    },
                                                    child: ListTile(
                                                      title: Text(option.nome),
                                                      tileColor: Colors.transparent,
                                                    ),
                                                  ))
                                                      .toList(),
                                                ),
                                              )
                                            )
                                          )
                                        );
                                      },
                                    )
                                )
                            )
                        )
                    ),
                  ),
                  Expanded(
                    child: Padding(
                        padding:  EdgeInsets.all(4),
                        child: Align(
                            child: Container(
                              child: TextField(
                                controller: _controllerAdicional,
                                keyboardType: TextInputType.number,
                                focusNode: _focusNodeAdic,
                                textInputAction: TextInputAction.done,
                                cursorColor: Colors.black,
                                onTap: (){_controllerAdicional.clear();},
                                style: TextStyle(
                                  color: cores.corMarromSF,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900
                                ),
                                decoration: InputDecoration(
                                  counterText: "",
                                  contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                  labelText: "Valor Adicional",
                                  labelStyle: TextStyle(color: cores.corMarromSF, fontWeight: FontWeight.w700),
                                  fillColor: Colors.white,
                                  hoverColor: cores.corMarromSF,
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            )
                        )
                    ),
                  )
                ]
            ),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                        padding:  EdgeInsets.all(4),
                        child: Align(
                            child: Container(
                                child: InputDecorator(
                                    decoration: InputDecoration(
                                      counterText: "",
                                      contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                      labelText: "Adic - 2",
                                      labelStyle: TextStyle(color: cores.corMarromSF, fontWeight: FontWeight.w700),
                                      fillColor: Colors.white,
                                      hoverColor: cores.corMarromSF,
                                      focusColor: cores.corMarromSF,
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: RawAutocomplete<ItemCardapio>(
                                      key: _obs2Key,
                                      focusNode: _focusNodeObs2,
                                      textEditingController: _controllerObs2,
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        return _listaAdicionaisFiltrada.where((ItemCardapio option) => option.nome.toLowerCase()
                                            .contains(textEditingValue.text.toLowerCase())
                                        ).toList();
                                      },
                                      displayStringForOption: _displayStringForOption,
                                      fieldViewBuilder: (BuildContext context,
                                          TextEditingController textEditingController,
                                          FocusNode focusNode,
                                          VoidCallback onFieldSubmitted) {
                                        return TextFormField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          onFieldSubmitted: (String value) {
                                            onFieldSubmitted();
                                          },
                                          onTap: (){
                                            if(!_controllerObs2.text.isEmpty)
                                            {
                                              _controllerObs2.clear();
                                              _valor_adic = _valor_adic - _valor_adic2;
                                              final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
                                              String valorAdicFormatado = currencyFormatter.format(_valor_adic);
                                              setState(() {
                                                _controllerAdicional.text = valorAdicFormatado.toString();
                                                FocusScope.of(context).unfocus();
                                              });
                                            }
                                          },
                                          textCapitalization: TextCapitalization.characters,
                                          textInputAction: TextInputAction.none,
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                          cursorColor: cores.corMarromSF,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                          ),
                                        );
                                      },
                                      optionsViewBuilder: (BuildContext context,
                                          AutocompleteOnSelected<ItemCardapio> onSelected, Iterable<ItemCardapio> options) {
                                        return Container(
                                            color: Colors.transparent,
                                            width: 300,
                                            height: 350,
                                            child: Scaffold(
                                                backgroundColor: Colors.transparent,
                                                body: Container(
                                                    color: Colors.white,
                                                    width: 300,
                                                    height: 350,
                                                    child: Container(
                                                      color: cores.corLaranjaSF.withOpacity(0.10),
                                                      width: 300,
                                                      height: 350,
                                                      child: ListView(
                                                        children: options
                                                            .map((ItemCardapio option) => GestureDetector(
                                                          onTap: () {
                                                            onSelected(option);
                                                            _adicional_selecionado = option;
                                                            _valor_adic2 = _adicional_selecionado.valor;
                                                            _valor_adic = _adicional_selecionado.valor + _valor_adic;
                                                            final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
                                                            String valorAdicFormatado = currencyFormatter.format(_valor_adic);
                                                            _total_item = _item_selecionado.valor + _valor_adic;
                                                            String valorTotalItemFormatado = currencyFormatter.format(_total_item);
                                                            setState(() {
                                                              _controllerAdicional.text = valorAdicFormatado.toString();
                                                              _valor_total_mostrar = valorTotalItemFormatado.toString();
                                                              FocusScope.of(context).unfocus();
                                                            });
                                                          },
                                                          child: ListTile(
                                                            title: Text(option.nome),
                                                            tileColor: Colors.transparent,
                                                          ),
                                                        ))
                                                            .toList(),
                                                      ),
                                                    )
                                                )
                                            )
                                        );
                                      },
                                    )
                                )
                            )
                        )
                    ),
                  ),
                  Expanded(
                    child: Padding(
                        padding:  EdgeInsets.all(4),
                        child: Align(
                            child: Container(
                              child: TextField(
                                controller: _controllerDesconto,
                                keyboardType: TextInputType.number,
                                focusNode: _focusNodeDsct,
                                textInputAction: TextInputAction.done,
                                cursorColor: cores.corMarromSF,
                                onTap: (){_controllerDesconto.clear();},
                                style: TextStyle(
                                  color: cores.corMarromSF,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900
                                ),
                                decoration: InputDecoration(
                                  counterText: "",
                                  contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                  labelText: "Desconto",
                                  labelStyle: TextStyle(color: cores.corMarromSF, fontWeight: FontWeight.w700),
                                  fillColor: Colors.white,
                                  hoverColor: cores.corMarromSF,
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            )
                        )
                    ),
                  )
                ]
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                    child: Padding(
                        padding:  EdgeInsets.all(4),
                        child: Align(
                            child: Container(
                              //width: 150,
                                child: InputDecorator(
                                    decoration: InputDecoration(
                                      counterText: "",
                                      contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                      labelText: "Adic - 3",
                                      labelStyle: TextStyle(color: const Color(0xff3d2314), fontWeight: FontWeight.w700),
                                      fillColor: Colors.white,
                                      hoverColor: const Color(0xff3d2314),
                                      focusColor: const Color(0xff3d2314),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: RawAutocomplete<ItemCardapio>(
                                      key: _obs3Key,
                                      focusNode: _focusNodeObs3,
                                      textEditingController: _controllerObs3,
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        return _listaAdicionaisFiltrada.where((ItemCardapio option) => option.nome.toLowerCase()
                                            .contains(textEditingValue.text.toLowerCase())
                                        ).toList();
                                      },
                                      displayStringForOption: _displayStringForOption,
                                      fieldViewBuilder: (BuildContext context,
                                          TextEditingController textEditingController,
                                          FocusNode focusNode,
                                          VoidCallback onFieldSubmitted) {
                                        return TextFormField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          onFieldSubmitted: (String value) {
                                            onFieldSubmitted();
                                          },
                                          onTap: (){
                                            if(!_controllerObs3.text.isEmpty)
                                            {
                                              _controllerObs3.clear();
                                              _valor_adic = _valor_adic - _valor_adic3;
                                              final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
                                              String valorAdicFormatado = currencyFormatter.format(_valor_adic);
                                              setState(() {
                                                _controllerAdicional.text = valorAdicFormatado.toString();
                                                FocusScope.of(context).unfocus();
                                              });
                                            }
                                          },
                                          textCapitalization: TextCapitalization.characters,
                                          textInputAction: TextInputAction.none,
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                          cursorColor: cores.corMarromSF,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                          ),
                                        );
                                      },
                                      optionsViewBuilder: (BuildContext context,
                                          AutocompleteOnSelected<ItemCardapio> onSelected, Iterable<ItemCardapio> options) {
                                        return Container(
                                            color: Colors.transparent,
                                            width: 300,
                                            height: 350,
                                            child: Scaffold(
                                                backgroundColor: Colors.transparent,
                                                body: Container(
                                                    color: Colors.white,
                                                    width: 300,
                                                    height: 350,
                                                    child: Container(
                                                      color: cores.corLaranjaSF.withOpacity(0.10),
                                                      width: 300,
                                                      height: 350,
                                                      child: ListView(
                                                        children: options
                                                            .map((ItemCardapio option) => GestureDetector(
                                                          onTap: () {
                                                            onSelected(option);
                                                            _adicional_selecionado = option;
                                                            _valor_adic3 = _adicional_selecionado.valor;
                                                            _valor_adic = _adicional_selecionado.valor + _valor_adic;
                                                            final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
                                                            String valorAdicFormatado = currencyFormatter.format(_valor_adic);
                                                            _total_item = _item_selecionado.valor + _valor_adic;
                                                            String valorTotalItemFormatado = currencyFormatter.format(_total_item);
                                                            setState(() {
                                                              _controllerAdicional.text = valorAdicFormatado.toString();
                                                              _valor_total_mostrar = valorTotalItemFormatado.toString();
                                                              FocusScope.of(context).unfocus();
                                                            });
                                                          },
                                                          child: ListTile(
                                                            title: Text(option.nome),
                                                            tileColor: Colors.transparent,
                                                          ),
                                                        ))
                                                            .toList(),
                                                      ),
                                                    )
                                                )
                                            )
                                        );
                                      },
                                    )
                                )
                            )
                        )
                    )
                ),
                Expanded(
                  child: Padding(
                      padding:  EdgeInsets.all(4),
                      child: Align(
                          child: Container(
                            child: TextField(
                              controller: _controllerQtd,
                              keyboardType: TextInputType.number,
                              focusNode: _focusNodeQtd,
                              textInputAction: TextInputAction.next,
                              cursorColor: cores.corMarromSF,
                              style: TextStyle(
                                color: cores.corMarromSF,
                                fontSize: 16,
                                fontWeight: FontWeight.w900
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "Quantidade",
                                labelStyle: TextStyle(color: cores.corLaranjaSF, fontWeight: FontWeight.w700),
                                fillColor: Colors.white,
                                hoverColor: cores.corLaranjaSF,
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: const Color(0xffff6900)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: const Color(0xffff6900)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          )
                      )
                  ),
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding:  EdgeInsets.all(4),
                    child: Container(
                      height: 40,
                      child: ElevatedButton(
                          onPressed: (){
                            setState(() {
                              _controllerAdicional.text = "";
                              _controllerObs1.text = "";
                              _controllerObs2.text = "";
                              _controllerObs3.text = "";
                              _valor_adic = 0;
                              _valor_adic1 = 0;
                              _valor_adic2 = 0;
                              _valor_adic3 = 0;
                              _total_item = _item_selecionado.valor;
                              final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
                              String formatado = currencyFormatter.format(_total_item);
                              _valor_total_mostrar = formatado;
                              FocusScope.of(context).unfocus();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                            primary: cores.corMarromSF,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text("Limpar Adicionais", style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w900),)
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child:Padding(
                      padding:  EdgeInsets.all(4),
                      child: Align(
                          child: Container(
                            //width: 150,
                              child: Text(
                                _valor_total_mostrar,
                                style: TextStyle(
                                    color: cores.corLaranjaSF,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28
                                ),
                              )
                          )
                      )
                  ),
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding:  EdgeInsets.all(4),
                    child: Container(
                      height: 40,
                      child: ElevatedButton(
                          onPressed: (){
                            setState(() {
                              _item_selecionado = ItemCardapio();
                              _adicional_selecionado = ItemCardapio();
                              _controllerDescricao.text = "";
                              _controllerAdicional.text = "";
                              _controllerDesconto.text = "";
                              _controllerObs1.text = "";
                              _controllerObs2.text = "";
                              _controllerObs3.text = "";
                              _controllerQtd.text = "";
                              _valor_adic = 0;
                              _valor_dsct = 0;
                              _valor_total_mostrar = "R\$ 0,00";
                              _valor_adic1 = 0;
                              _valor_adic2 = 0;
                              _valor_adic3 = 0;
                              FocusScope.of(context).unfocus();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                            primary: cores.corMarromSF,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text("Cancelar", style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w900),)
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:  EdgeInsets.all(4),
                    child: Container(
                      height: 40,
                      child: ElevatedButton(
                          onPressed: (){
                            bool ok = false;
                            //validação
                            ItemCardapio item = ItemCardapio();
                            if(_controllerDescricao.text.isEmpty ||
                                (_listaItens.firstWhere((it) => it.nome == _controllerDescricao.text, orElse: () => item)) == item ||
                                _controllerQtd.text.isEmpty  ||
                                num.parse(_controllerQtd.text) <= 0) {
                              ok = false;
                            }
                            else {
                              ok = true;
                            }
                            //calculo total
                            if(ok){
                              //verificar ultimoID
                              int _id_item = 0;
                              if(_listaItensMesa.length > 0)
                                _id_item = _listaItensMesa.last.id_item + 1;
                              else
                                _id_item = 1;

                              _total_item_vezes_qtd = _total_item * (num.parse(_controllerQtd.text));
                              //salvar
                              ItemMesa _item_salvar = ItemMesa();
                              _adicionais_final = _controllerObs1.text + "\n" + _controllerObs2.text + "\n" + _controllerObs3.text;
                              _adicionais_final = _adicionais_final.trim();

                              _item_salvar.id_item = _id_item;
                              _item_salvar.id_mesa = widget._numMesa;
                              _item_salvar.desc_item = _item_selecionado.nome;
                              _item_salvar.obs_adici = _adicionais_final;
                              _item_salvar.valor_uni = _total_item;
                              _item_salvar.valor_tot = _total_item_vezes_qtd;
                              _item_salvar.qtd = int.parse(_controllerQtd.text);

                              if(_listaItensMesa.length > 0)
                                {
                                  ItemMesa item = ItemMesa();
                                  if(_listaItensMesa.firstWhere((it) => it.desc_item == _item_salvar.desc_item, orElse: () => item) != item && _listaItensMesa.firstWhere((it) => it.obs_adici == _item_salvar.obs_adici, orElse: () => item) != item)
                                  {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
                                    ItemMesa _ja_existe = _listaItensMesa.firstWhere((it) => it.desc_item == _item_salvar.desc_item && it.obs_adici == _item_salvar.obs_adici);
                                    int _indice = _listaItensMesa.indexOf(_ja_existe);
                                    num _novo_valor = _ja_existe.valor_tot + _item_salvar.valor_tot;
                                    int _nova_qtd = _ja_existe.qtd + _item_salvar.qtd;
                                    _ja_existe.valor_tot = _novo_valor;
                                    _ja_existe.qtd = _nova_qtd;
                                    _listaItensMesa[_indice] = _ja_existe;
                                    _limpar_dialogo();
                                    _recupera_itens_mesa();
                                  }
                                  else{
                                    _limpar_dialogo();
                                    _listaItensMesa.add(_item_salvar);
                                    _recupera_itens_mesa();
                                    //_salvarItemMesa(_item_salvar);
                                  }
                                }
                              else{
                                _limpar_dialogo();
                                _listaItensMesa.add(_item_salvar);
                                _recupera_itens_mesa();
                                //_salvarItemMesa(_item_salvar);
                              }
                            }
                            else
                              {
                                final snackBar = SnackBar(
                                  content: const Text('Preenchimento dos campos incorreto. Verifique e tente novamente.', style: TextStyle(color: Colors.white),),
                                  backgroundColor: cores.corLaranjaSF,
                                  duration: Duration(seconds: 2),
                                  action: SnackBarAction(
                                    label: 'Ok',
                                    textColor: cores.corMarromSF,
                                    onPressed: () {
                                      // Some code to undo the change.
                                    },
                                  ),
                                );

                                // Find the ScaffoldMessenger in the widget tree
                                // and use it to show a SnackBar.
                                ScaffoldMessenger.of(context).showSnackBar(snackBar);
                              }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                            primary: cores.corMarromSF,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text("Salvar", style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w900),)
                      ),
                    ),
                  ),
                )
              ],
            ),
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
                            color: cores.corLaranjaSF.withOpacity(0.20),
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
                                                    mainAxisAlignment: MainAxisAlignment.start,
                                                    children: <Widget>[
                                                      Padding(
                                                        padding: EdgeInsets.fromLTRB(2, 4, 2, 2),
                                                        child: Text(
                                                          _listaItensMesa[index].desc_item,
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            color: cores.corMarromSF,
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
                                                                  color: cores.corLaranjaSF,
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
                                                            color: cores.corMarromSF,
                                                            fontSize: (20),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Align(
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
                            color: cores.corLaranjaSF.withOpacity(0.20),
                            child:ListView.builder(
                              itemCount: _listaItensMesa.length,
                              shrinkWrap: true,
                              padding: EdgeInsets.fromLTRB(4, 4, 4, 48),
                              scrollDirection: Axis.vertical,
                              itemBuilder: (BuildContext, index){
                                return Card(
                                  child: ListTile(
                                    leading:  CircleAvatar(
                                      backgroundColor: Colors.green,
                                      child: Icon(
                                        Icons.check, color: Colors.white,
                                      ),
                                    ),
                                    title: Padding(
                                      padding: EdgeInsets.fromLTRB(0, 4, 0, 2),
                                      child: Text(
                                        _listaItensMesa[index].desc_item,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: cores.corMarromSF,
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
                                              color: cores.corLaranjaSF,
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
                                              color: cores.corMarromSF,
                                              fontSize: (16),
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
            Visibility(
                visible: _visibilitySemItens,
                child: Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      "Sem itens inseridos",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black26,
                        fontSize: (24),
                      ),
                    ),
                  )
                )
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if(_listaItensMesa.length > 0){
            if(widget._parametro_tipo_adicionar == 0){
              _gerar_dialogo_registrar();
              }
            if(widget._parametro_tipo_adicionar == 2){
              _gerar_dialogo_registrar_balcao();
            }
            if(widget._parametro_tipo_adicionar == 1){
              _gerar_dialogo_registrar_entrega();
            }
            if(widget._parametro_tipo_adicionar == 4){
              _gerar_dialogo_add_itens_balcao();
            }
            if(widget._parametro_tipo_adicionar == 3){
              _gerar_dialogo_add_itens_entrega();
            }
          }
          else{
            final snackBar = SnackBar(
              content: const Text('Não existem itens para inserção na mesa', style: TextStyle(color: Colors.white),),
              backgroundColor: cores.corLaranjaSF,
              duration: Duration(seconds: 2),
              action: SnackBarAction(
                label: 'Ok',
                textColor: cores.corMarromSF,
                onPressed: () {
                  // Some code to undo the change.
                },
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          }
        },
        label: Column(
            children: <Widget>[
              const Text('Registrar', style: TextStyle(fontSize: 20)),
              Text('Total: ' + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_inserir_mesa()), style: TextStyle(fontSize: 14))
            ],
        ),
        icon: const Icon(Icons.note_add),
        backgroundColor: cores.corLaranjaSF,
        splashColor: cores.corMarromSF,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  _criar_listener_valor_adic()
  {
    _focusNodeAdic.addListener(() {
      if(!_focusNodeAdic.hasFocus)
      {
        bool parse = true;
        num valorInformado = 0;
        try{
          valorInformado = num.parse(_controllerAdicional.text);
        }
        catch(e) {
          parse = false;
        }
        if(!parse || valorInformado <= 0 || _controllerAdicional.text.isEmpty || _controllerDescricao.text.isEmpty)
        {
          _controllerAdicional.text = "";
          _valor_adic = 0;
          _valor_adic1 = 0;
          _valor_adic2 = 0;
          _valor_adic3 = 0;
          final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
          _total_item = _item_selecionado.valor + _valor_adic - _valor_dsct;
          String valorTotalItemFormatado = currencyFormatter.format(_total_item);
          setState(() {
            _valor_total_mostrar = valorTotalItemFormatado.toString();
          });
          return;
        }
        else
        {
          _valor_adic1 = 0;
          _valor_adic2 = 0;
          _valor_adic3 = 0;
          _valor_adic = num.parse(_controllerAdicional.text);
          final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
          String valorAdicFormatado = currencyFormatter.format(_valor_adic);
          _total_item = _item_selecionado.valor + _valor_adic - _valor_dsct;
          String valorTotalItemFormatado = currencyFormatter.format(_total_item);
          setState(() {
            _controllerAdicional.text = valorAdicFormatado.toString();
            _valor_total_mostrar = valorTotalItemFormatado.toString();
          });
        }
      }
    });
  }
  _criar_listener_valor_dsct()
  {
    _focusNodeDsct.addListener(() {
      if(!_focusNodeDsct.hasFocus)
      {
        bool parse = true;
        num valorInformado = 0;
        try{
          valorInformado = num.parse(_controllerDesconto.text);
        }
        catch(e) {
          parse = false;
        }
        if(!parse || valorInformado <= 0 || _controllerDesconto.text.isEmpty || _controllerDesconto.text.isEmpty)
        {
          _controllerDesconto.text = "";
          _valor_dsct = 0;
          final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
          _total_item = _item_selecionado.valor + _valor_adic - _valor_dsct;
          String valorTotalItemFormatado = currencyFormatter.format(_total_item);
          setState(() {
            _valor_total_mostrar = valorTotalItemFormatado.toString();
          });
          return;
        }
        else
        {
          _valor_dsct = num.parse(_controllerDesconto.text);
          final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
          String valorDescFormatado = currencyFormatter.format(_valor_dsct);
          _total_item = _item_selecionado.valor + _valor_adic - _valor_dsct;
          if(_total_item < 0)
          {
            _controllerDesconto.text = "";
            _valor_dsct = 0;
            _total_item = _item_selecionado.valor + _valor_adic - _valor_dsct;
            String valorTotalItemFormatado = currencyFormatter.format(_total_item);
            setState(() {
              _valor_total_mostrar = valorTotalItemFormatado.toString();
            });
          }
          else
            {
              String valorTotalItemFormatado = currencyFormatter.format(_total_item);
              setState(() {
                _controllerDesconto.text = valorDescFormatado.toString();
                _valor_total_mostrar = valorTotalItemFormatado.toString();
              });
            }
        }
      }
    });
  }

  _carrega_adicionais()
  {
    _listaAdicionaisFiltrada.clear();
    if(_item_selecionado.grupo == 1 && _item_selecionado.tipo == 1)//adicionais de lanches
    {
      for(ItemCardapio ds in _listaAdicionais)
      {
        if(ds.tipo == 9)//9 - adicionais de lanches
        {
          if(!ds.nome.contains("+"))
            ds.nome = "+" + ds.nome;
          _listaAdicionaisFiltrada.add(ds);
        }
      }
    }
    if(_item_selecionado.grupo == 4 && _item_selecionado.tipo == 1)  //adicional de pastéis
    {
      for(ItemCardapio ds in _listaAdicionais)
      {
        if(ds.tipo == 8)//9 - adicionais de pasteis
        {
          if(!ds.nome.contains("+"))
            ds.nome = "+" + ds.nome;
          _listaAdicionaisFiltrada.add(ds);
        }
      }
    }
    if(_item_selecionado.grupo == 5 && _item_selecionado.tipo == 1) //adicionais de porções
    {
      for(ItemCardapio ds in _listaAdicionais)
      {
        if(ds.tipo == 7)//9 - adicionais de porções
        {
          if(!ds.nome.contains("+"))
            ds.nome = "+" + ds.nome;
          _listaAdicionaisFiltrada.add(ds);
        }
      }
    }
  }

  _recupera_itens_mesa() async
  {
    setState(() {
      if(_listaItensMesa.length > 0)
        {
          if(_parametro_tipo_visualizacao == 0) {
            _visibilityCard = true;
            _visibilityList = false;
            _visibilityProgress = false;
            _visibilitySemItens = false;
          }

          else{
            _visibilityCard = false;
            _visibilityList = true;
            _visibilityProgress = false;
            _visibilitySemItens = false;
          }
        }
      else
        {
          _visibilityProgress = false;
          _visibilitySemItens = true;
        }
    });
  }
  _gerar_dialogo_deletar()
  {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text('Remover Item'),
            content: const Text('Deseja realmente remover este item?'),
            actions: [
              TextButton(
                  onPressed: () {
                    _listaItensMesa.removeAt(_indice_deletar);
                    _limpar_dialogo();
                    _recupera_itens_mesa();
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
  Color getColor(Set<MaterialState> states) {
    const Set<MaterialState> interactiveStates = <MaterialState>{
      MaterialState.pressed,
      MaterialState.hovered,
      MaterialState.focused,
    };
    if (states.any(interactiveStates.contains)) {
      return Color(0xff3d2314);
    }
    return Color(0xffff6900);
  }

  _gerar_dialogo_registrar()
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
                                      'Inserir Itens: Mesa  ' + widget._numMesa.toString(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16, color: CustomColors().corMarromSF, fontWeight: FontWeight.bold),),
                                  ),
                                  Text('\n'+ NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_inserir_mesa()), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.w700),),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(8, 16, 8, 16),
                                    child: Align(
                                        child: Container(
                                          child: TextField(
                                            controller: _controllerObsCozinha,
                                            keyboardType: TextInputType.text,
                                            textCapitalization: TextCapitalization.characters,
                                            textInputAction: TextInputAction.done,
                                            cursorColor: cores.corMarromSF,
                                            onTap: (){},
                                            style: TextStyle(
                                              color: cores.corLaranjaSF,
                                              fontSize: 16,
                                            ),
                                            decoration: InputDecoration(
                                              counterText: "",
                                              contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                              labelText: "Obs. para a cozinha",
                                              labelStyle: TextStyle(color: cores.corMarromSF),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                borderRadius: BorderRadius.circular(15),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                borderRadius: BorderRadius.circular(15),
                                              ),
                                            ),
                                          ),
                                        )
                                    )
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Checkbox(
                                        checkColor: Colors.white,
                                        fillColor: MaterialStateProperty.resolveWith(getColor),
                                        value: _cb_imprimir,
                                        onChanged: (bool? valor){
                                          setState(() {
                                            _cb_imprimir = valor!;
                                            if(_cb_imprimir == true)
                                              {
                                                _param_imprimir = 0; //imprime
                                              }
                                            else
                                              {
                                                _param_imprimir = 1;//não imprime
                                              }
                                          });
                                        },
                                      ),
                                      Text('Imprimir pedido?',style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold))
                                      ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      TextButton(
                                          onPressed: () {
                                            _obs_cozinha = _controllerObsCozinha.text;
                                            Navigator.of(context).pop();
                                            _registra_itens_mesa();
                                          },
                                          child: const Text('Confirmar',style: TextStyle(fontSize: 16, color: const Color(0xffff6900), fontWeight: FontWeight.bold))
                                      ),
                                      TextButton(
                                          onPressed: () {
                                            // Close the dialog
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Cancelar', style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold))
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
  _gerar_dialogo_registrar_balcao()
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
                      child: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState){
                          return SingleChildScrollView(
                              child: Container(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                                        child: Text(
                                          'Nova Retirada no Balcão',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 16, color: CustomColors().corMarromSF, fontWeight: FontWeight.bold),),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Expanded(
                                              child: Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Align(
                                                      child: Container(
                                                        child: TextField(
                                                          controller: _ctlNomeBalc,
                                                          keyboardType: TextInputType.text,
                                                          textCapitalization: TextCapitalization.characters,
                                                          textInputAction: TextInputAction.done,
                                                          cursorColor: cores.corMarromSF,
                                                          onTap: (){},
                                                          style: TextStyle(
                                                            color: cores.corLaranjaSF,
                                                            fontSize: 16,
                                                          ),
                                                          decoration: InputDecoration(
                                                            counterText: "",
                                                            contentPadding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                                                            labelText: "Nome",
                                                            labelStyle: TextStyle(color: cores.corMarromSF),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                              borderRadius: BorderRadius.circular(15),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                              borderRadius: BorderRadius.circular(15),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                  )
                                              )
                                          ),
                                          Expanded(
                                              child: Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Align(
                                                      child: Container(
                                                        child: TextField(
                                                          controller: _ctlCeluBalc,
                                                          keyboardType: TextInputType.number,
                                                          textCapitalization: TextCapitalization.characters,
                                                          textInputAction: TextInputAction.done,
                                                          cursorColor: cores.corMarromSF,
                                                          inputFormatters: [mascaraCelular],
                                                          onTap: (){},
                                                          style: TextStyle(
                                                            color: cores.corLaranjaSF,
                                                            fontSize: 16,
                                                          ),
                                                          decoration: InputDecoration(
                                                            counterText: "",
                                                            contentPadding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                                                            labelText: "Celular",
                                                            labelStyle: TextStyle(color: cores.corMarromSF),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                              borderRadius: BorderRadius.circular(15),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                              borderRadius: BorderRadius.circular(15),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                  )
                                              )
                                          )
                                        ],
                                      ),
                                      Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: <Widget>[
                                          Expanded(
                                                child: Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Align(
                                                        child: Container(
                                                          child: Text('Total:'+'\n'+ NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_inserir_mesa() + _valor_taxa), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.w700),),
                                                        )
                                                    )
                                                )
                                            )
                                          ]
                                      ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
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
                                                      _tipo_pagamento = 0;
                                                      FocusScope.of(context).unfocus();
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
                                                      _tipo_pagamento = 1;
                                                      FocusScope.of(context).unfocus();
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
                                                      _tipo_pagamento = 2;
                                                      FocusScope.of(context).unfocus();
                                                    });
                                                  },
                                                ),
                                                const Text('Pix', style: TextStyle(color: const Color(0xff3d2314))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                          padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                                          child: Align(
                                              child: Container(
                                                child: TextField(
                                                  controller: _controllerObsCozinha,
                                                  keyboardType: TextInputType.text,
                                                  textCapitalization: TextCapitalization.characters,
                                                  textInputAction: TextInputAction.done,
                                                  cursorColor: cores.corMarromSF,
                                                  onTap: (){},
                                                  style: TextStyle(
                                                    color: cores.corLaranjaSF,
                                                    fontSize: 16,
                                                  ),
                                                  decoration: InputDecoration(
                                                    counterText: "",
                                                    contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                                    labelText: "Obs. para a cozinha",
                                                    labelStyle: TextStyle(color: cores.corMarromSF),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                      borderRadius: BorderRadius.circular(15),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                      borderRadius: BorderRadius.circular(15),
                                                    ),
                                                  ),
                                                ),
                                              )
                                          )
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Checkbox(
                                            checkColor: Colors.white,
                                            fillColor: MaterialStateProperty.resolveWith(getColor),
                                            value: _cb_imprimir,
                                            onChanged: (bool? valor){
                                              setState(() {
                                                _cb_imprimir = valor!;
                                                if(_cb_imprimir == true)
                                                {
                                                  _param_imprimir = 0; //imprime
                                                }
                                                else
                                                {
                                                  _param_imprimir = 1;//não imprime
                                                }
                                              });
                                            },
                                          ),
                                          Text('Imprimir pedido?',style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold))
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          TextButton(
                                              onPressed: () {
                                                if(_ctlNomeBalc.text.isEmpty || _ctlNomeBalc.text == "" || _ctlCeluBalc.text.isEmpty || _ctlCeluBalc.text == ""){
                                                  final snackBar = SnackBar(
                                                    content: const Text('Preenchimento dos campos incorreto. Verifique e tente novamente.', style: TextStyle(color: Colors.white),),
                                                    backgroundColor: cores.corLaranjaSF,
                                                    duration: Duration(seconds: 2),
                                                    action: SnackBarAction(
                                                      label: 'Ok',
                                                      textColor: cores.corMarromSF,
                                                      onPressed: () {
                                                        // Some code to undo the change.
                                                      },
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                                }
                                                else
                                                {
                                                  if(_tipo_pagamento == -1){
                                                    final snackBar = SnackBar(
                                                      content: const Text('Informe um tipo de pagamento!', style: TextStyle(color: Colors.white),),
                                                      backgroundColor: cores.corLaranjaSF,
                                                      duration: Duration(seconds: 2),
                                                      action: SnackBarAction(
                                                        label: 'Ok',
                                                        textColor: cores.corMarromSF,
                                                        onPressed: () {
                                                          // Some code to undo the change.
                                                        },
                                                      ),
                                                    );
                                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                                  }
                                                  else
                                                  {
                                                    _obs_cozinha = _controllerObsCozinha.text;
                                                    _blc_nome_cli = _ctlNomeBalc.text;
                                                    _blc_celu_cli = _ctlCeluBalc.text;
                                                    Navigator.of(context).pop();
                                                    _registra_itens_balcao();
                                                  }
                                                }
                                              },
                                              child: const Text('Confirmar',style: TextStyle(fontSize: 16, color: const Color(0xffff6900), fontWeight: FontWeight.bold))
                                          ),
                                          TextButton(
                                              onPressed: () {
                                                // Close the dialog
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Cancelar', style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold))
                                          )
                                        ],
                                      )
                                    ],
                                  )
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
  _gerar_dialogo_registrar_entrega()
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
                      child: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState){
                          return SingleChildScrollView(
                            child: Container(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                                      child: Text(
                                        'Nova Entrega',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 16, color: CustomColors().corMarromSF, fontWeight: FontWeight.bold),),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Expanded(
                                            child: Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Align(
                                                    child: Container(
                                                      child: TextField(
                                                        controller: _ctlNome,
                                                        keyboardType: TextInputType.text,
                                                        textCapitalization: TextCapitalization.characters,
                                                        textInputAction: TextInputAction.done,
                                                        cursorColor: cores.corMarromSF,
                                                        onTap: (){},
                                                        style: TextStyle(
                                                          color: cores.corLaranjaSF,
                                                          fontSize: 16,
                                                        ),
                                                        decoration: InputDecoration(
                                                          counterText: "",
                                                          contentPadding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                                                          labelText: "Nome",
                                                          labelStyle: TextStyle(color: cores.corMarromSF),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                )
                                            )
                                        ),
                                        Expanded(
                                            child: Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Align(
                                                    child: Container(
                                                      child: TextField(
                                                        controller: _ctlCelular,
                                                        keyboardType: TextInputType.number,
                                                        textCapitalization: TextCapitalization.characters,
                                                        textInputAction: TextInputAction.done,
                                                        cursorColor: cores.corMarromSF,
                                                        inputFormatters: [mascaraCelular],
                                                        onTap: (){},
                                                        style: TextStyle(
                                                          color: cores.corLaranjaSF,
                                                          fontSize: 16,
                                                        ),
                                                        decoration: InputDecoration(
                                                          counterText: "",
                                                          contentPadding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                                                          labelText: "Celular",
                                                          labelStyle: TextStyle(color: cores.corMarromSF),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                )
                                            )
                                        )
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Expanded(
                                            child: Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Align(
                                                    child: Container(
                                                      child: TextField(
                                                        controller: _ctlRua,
                                                        keyboardType: TextInputType.text,
                                                        textCapitalization: TextCapitalization.characters,
                                                        textInputAction: TextInputAction.done,
                                                        cursorColor: cores.corMarromSF,
                                                        onTap: (){},
                                                        style: TextStyle(
                                                          color: cores.corLaranjaSF,
                                                          fontSize: 16,
                                                        ),
                                                        decoration: InputDecoration(
                                                          counterText: "",
                                                          contentPadding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                                                          labelText: "Rua",
                                                          labelStyle: TextStyle(color: cores.corMarromSF),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                )
                                            )
                                        ),
                                        Expanded(
                                            child: Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Align(
                                                    child: Container(
                                                      child: TextField(
                                                        controller: _ctlNumero,
                                                        keyboardType: TextInputType.number,
                                                        textCapitalization: TextCapitalization.characters,
                                                        textInputAction: TextInputAction.done,
                                                        cursorColor: cores.corMarromSF,
                                                        onTap: (){},
                                                        style: TextStyle(
                                                          color: cores.corLaranjaSF,
                                                          fontSize: 16,
                                                        ),
                                                        decoration: InputDecoration(
                                                          counterText: "",
                                                          contentPadding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                                                          labelText: "Numero",
                                                          labelStyle: TextStyle(color: cores.corMarromSF),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                )
                                            )
                                        )
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Expanded(
                                          child: Padding(
                                              padding:  EdgeInsets.all(4),
                                              child: Align(
                                                  child: Container(
                                                      child: InputDecorator(
                                                          decoration: InputDecoration(
                                                            counterText: "",
                                                            contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                                            labelText: "Bairro",
                                                            labelStyle: TextStyle(color: cores.corMarromSF,),
                                                            fillColor: Colors.white,
                                                            enabledBorder: OutlineInputBorder(
                                                              borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                              borderRadius: BorderRadius.circular(15),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                              borderRadius: BorderRadius.circular(15),
                                                            ),
                                                          ),
                                                          child: RawAutocomplete<Taxa>(
                                                            key: _bairroKey,
                                                            focusNode: _focusNodeBairro,
                                                            textEditingController: _ctlBairro,
                                                            optionsBuilder: (TextEditingValue textEditingValue) {
                                                              return _listaTaxas.where((Taxa option) => option.bairro.toLowerCase()
                                                                  .contains(textEditingValue.text.toLowerCase())
                                                              ).toList();
                                                            },
                                                            displayStringForOption: _displayStringForOptionBairro,
                                                            fieldViewBuilder: (BuildContext context,
                                                                TextEditingController textEditingController,
                                                                FocusNode focusNode,
                                                                VoidCallback onFieldSubmitted) {
                                                              return TextFormField(
                                                                onTap: (){
                                                                  if(!_ctlBairro.text.isEmpty)
                                                                  {
                                                                    _ctlBairro.clear();
                                                                  }
                                                                },
                                                                textCapitalization: TextCapitalization.characters,
                                                                controller: textEditingController,
                                                                textInputAction: TextInputAction.none,
                                                                focusNode: focusNode,
                                                                onFieldSubmitted: (String value) {
                                                                  onFieldSubmitted();
                                                                },
                                                                style: TextStyle(color: cores.corLaranjaSF),
                                                                cursorColor: cores.corMarromSF,
                                                                decoration: InputDecoration(
                                                                  border: InputBorder.none,
                                                                ),
                                                              );
                                                            },
                                                            optionsViewBuilder: (BuildContext context,
                                                                AutocompleteOnSelected<Taxa> onSelected, Iterable<Taxa> options) {
                                                              return Container(
                                                                  color: Colors.transparent,
                                                                  width: 300,
                                                                  height: 350,
                                                                  child: Scaffold(
                                                                      backgroundColor: Colors.transparent,
                                                                      body: Container(
                                                                          color: Colors.white,
                                                                          width: 300,
                                                                          height: 350,
                                                                          child: Container(
                                                                            color: cores.corLaranjaSF.withOpacity(0.10),
                                                                            width: 300,
                                                                            height: 350,
                                                                            child: ListView(
                                                                              children: options
                                                                                  .map((Taxa option) => GestureDetector(
                                                                                onTap: () {
                                                                                  onSelected(option);
                                                                                  _taxa_selecionada = option;
                                                                                  _valor_taxa = _taxa_selecionada.valor;
                                                                                  final currencyFormatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
                                                                                  String valorAdicFormatado = currencyFormatter.format(_valor_taxa);
                                                                                  String valorTotalItemFormatado = currencyFormatter.format(_total_item);
                                                                                  setState(() {
                                                                                    FocusScope.of(context).unfocus();
                                                                                  });
                                                                                },
                                                                                child: ListTile(
                                                                                  title: Text(option.bairro),
                                                                                  tileColor: Colors.transparent,
                                                                                ),
                                                                              ))
                                                                                  .toList(),
                                                                            ),
                                                                          )
                                                                      )
                                                                  )
                                                              );
                                                            },
                                                          )
                                                      )
                                                  )
                                              )
                                          ),
                                        ),
                                        Expanded(
                                            child: Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Align(
                                                    child: Container(
                                                      child: TextField(
                                                        controller: _ctlRef,
                                                        keyboardType: TextInputType.text,
                                                        textCapitalization: TextCapitalization.characters,
                                                        textInputAction: TextInputAction.done,
                                                        cursorColor: cores.corMarromSF,
                                                        onTap: (){},
                                                        style: TextStyle(
                                                          color: cores.corLaranjaSF,
                                                          fontSize: 16,
                                                        ),
                                                        decoration: InputDecoration(
                                                          counterText: "",
                                                          contentPadding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                                                          labelText: "Complemento",
                                                          labelStyle: TextStyle(color: cores.corMarromSF),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                            borderRadius: BorderRadius.circular(15),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                )
                                            )
                                        )
                                      ],
                                    ),
                                    Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: <Widget>[
                                          Expanded(
                                              child: Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Align(
                                                      child: Container(
                                                        child: Text('Taxa:'+'\n'+ NumberFormat.simpleCurrency(locale: 'pt_BR').format(_valor_taxa), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: cores.corLaranjaSF, fontWeight: FontWeight.w700),),
                                                      )
                                                  )
                                              )
                                          ),
                                          Expanded(
                                              child: Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Align(
                                                      child: Container(
                                                        child: Text('Total:'+'\n'+ NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_inserir_mesa() + _valor_taxa), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.w700),),
                                                      )
                                                  )
                                              )
                                          )
                                        ]
                                    ),
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
                                                    _tipo_pagamento = 0;
                                                    FocusScope.of(context).unfocus();
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
                                                    _tipo_pagamento = 1;
                                                    FocusScope.of(context).unfocus();
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
                                                    _tipo_pagamento = 2;
                                                    FocusScope.of(context).unfocus();
                                                  });
                                                },
                                              ),
                                              const Text('Pix', style: TextStyle(color: const Color(0xff3d2314))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                        padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                                        child: Align(
                                            child: Container(
                                              child: TextField(
                                                controller: _controllerObsCozinha,
                                                keyboardType: TextInputType.text,
                                                textCapitalization: TextCapitalization.characters,
                                                textInputAction: TextInputAction.done,
                                                cursorColor: cores.corMarromSF,
                                                onTap: (){},
                                                style: TextStyle(
                                                  color: cores.corLaranjaSF,
                                                  fontSize: 16,
                                                ),
                                                decoration: InputDecoration(
                                                  counterText: "",
                                                  contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                                  labelText: "Obs. para a cozinha",
                                                  labelStyle: TextStyle(color: cores.corMarromSF),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                    borderRadius: BorderRadius.circular(15),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderSide: const BorderSide(width: 2, color: const Color(0xff3d2314)),
                                                    borderRadius: BorderRadius.circular(15),
                                                  ),
                                                ),
                                              ),
                                            )
                                        )
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Checkbox(
                                          checkColor: Colors.white,
                                          fillColor: MaterialStateProperty.resolveWith(getColor),
                                          value: _cb_imprimir,
                                          onChanged: (bool? valor){
                                            setState(() {
                                              _cb_imprimir = valor!;
                                              if(_cb_imprimir == true)
                                              {
                                                _param_imprimir = 0; //imprime
                                              }
                                              else
                                              {
                                                _param_imprimir = 1;//não imprime
                                              }
                                            });
                                          },
                                        ),
                                        Text('Imprimir pedido?',style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold))
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        TextButton(
                                            onPressed: () {
                                              if(_ctlNome.text.isEmpty || _ctlNome.text == ""||
                                                  _ctlCelular.text.isEmpty || _ctlCelular.text == ""||
                                                  _ctlRua.text.isEmpty || _ctlRua.text == ""||
                                                  _ctlBairro.text.isEmpty || _ctlBairro.text == ""){
                                                final snackBar = SnackBar(
                                                  content: const Text('Preenchimento dos campos incorreto. Verifique e tente novamente.', style: TextStyle(color: Colors.white),),
                                                  backgroundColor: cores.corLaranjaSF,
                                                  duration: Duration(seconds: 2),
                                                  action: SnackBarAction(
                                                    label: 'Ok',
                                                    textColor: cores.corMarromSF,
                                                    onPressed: () {
                                                      // Some code to undo the change.
                                                    },
                                                  ),
                                                );
                                                ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                              }
                                              else
                                              {
                                                if(_tipo_pagamento == -1){
                                                  final snackBar = SnackBar(
                                                    content: const Text('Informe um tipo de pagamento!', style: TextStyle(color: Colors.white),),
                                                    backgroundColor: cores.corLaranjaSF,
                                                    duration: Duration(seconds: 2),
                                                    action: SnackBarAction(
                                                      label: 'Ok',
                                                      textColor: cores.corMarromSF,
                                                      onPressed: () {
                                                        // Some code to undo the change.
                                                      },
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                                }
                                                else
                                                {
                                                  _obs_cozinha = _controllerObsCozinha.text;
                                                  _ent_nome_cli = _ctlNome.text;
                                                  _ent_celu_cli = _ctlCelular.text;
                                                  _ent_rua_cli = _ctlRua.text;
                                                  _ent_nume_cli = _ctlNumero.text;
                                                  _ent_bair_cli = _ctlBairro.text;
                                                  _ent_refe_cli = _ctlRef.text;
                                                  Navigator.of(context).pop();
                                                  _registra_itens_entrega();
                                                }
                                              }
                                            },
                                            child: const Text('Confirmar',style: TextStyle(fontSize: 16, color: const Color(0xffff6900), fontWeight: FontWeight.bold))
                                        ),
                                        TextButton(
                                            onPressed: () {
                                              // Close the dialog
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Cancelar', style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold))
                                        )
                                      ],
                                    )
                                  ],
                                )
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
  _gerar_dialogo_add_itens_balcao()
  {
    Pedido pedido_alterar = Pedido();
    pedido_alterar = _listaPedidos.firstWhere((it) => it.identificador == widget._identificador_pedido);

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
                                      child: AutoSizeText(
                                        'Inserir Itens: Pedido de ' + pedido_alterar.nome_cliente.toString(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 16, color: CustomColors().corMarromSF, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        minFontSize: 12,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                  ),
                                  Text('\n'+ NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_inserir_mesa()), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.w700),),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _atualiza_itens_balcao(pedido_alterar);
                                          },
                                          child: const Text('Confirmar',style: TextStyle(fontSize: 16, color: const Color(0xffff6900), fontWeight: FontWeight.bold))
                                      ),
                                      TextButton(
                                          onPressed: () {
                                            // Close the dialog
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Cancelar', style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold))
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

  _gerar_dialogo_add_itens_entrega()
  {
    Pedido pedido_alterar = Pedido();
    pedido_alterar = _listaPedidos.firstWhere((it) => it.identificador == widget._identificador_pedido);
    _taxa_atualizar_pedido = _calcula_valor_taxa_reimprimir(pedido_alterar.total);
    
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
                                    child: AutoSizeText(
                                      'Inserir Itens: Pedido de ' + pedido_alterar.nome_cliente.toString(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16, color: CustomColors().corMarromSF, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      minFontSize: 12,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  ),
                                  Text('\n'+ NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_inserir_mesa()), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.w700),),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _atualiza_itens_entrega(pedido_alterar);
                                          },
                                          child: const Text('Confirmar',style: TextStyle(fontSize: 16, color: const Color(0xffff6900), fontWeight: FontWeight.bold))
                                      ),
                                      TextButton(
                                          onPressed: () {
                                            // Close the dialog
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Cancelar', style: TextStyle(fontSize: 16, color: const Color(0xff3d2314), fontWeight: FontWeight.bold))
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

  _registra_itens_mesa() async{
    mostrarDialogoSalvando();
    //realizamos a impressão dos dados
    if(_param_imprimir == 0)
      _imprimir_pedido();
    //recuperamos infos mesa
    Mesa _mesa_salvar = Mesa();
    Mesa _mesa_recuperada = Mesa();
    _listaItensExistentesMesa.clear();
    final refmesa = FirebaseDatabase.instance.ref();
    final snapshot = await refmesa.child("mesas/" + widget._numMesa.toString()).get();
    if (snapshot.exists) {
      final json = snapshot.value as Map<dynamic, dynamic>;
      _mesa_recuperada = Mesa.fromJson(json);
    }
    //verificamos os itens já inseridos
    final refItemMesa = FirebaseDatabase.instance.ref();
    final snapshot1 = await refItemMesa.child("itens-mesa/" + widget._numMesa.toString()).get();
    if (snapshot1.exists) {
      final json = snapshot1.value as List;
      for(DataSnapshot ds in snapshot1.children)
      {
        ItemMesa _itemLista = ItemMesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = ItemMesa.fromJson(json);
        _listaItensExistentesMesa.add(_itemLista);
      }
    }
    //verificação de id
    int _ult_id_registrado = 0;
    if(_listaItensExistentesMesa.length > 0)
      _ult_id_registrado = _listaItensExistentesMesa.last.id_item;

    //verificamos se já existem itens inseridos iguais aos que estão sendo inseridos para unir as quantidades e valores
    if(_listaItensExistentesMesa.length > 0)
    {
      for(int i = 0; i < _listaItensMesa.length; i++)
      {
        String desc_item_atual = _listaItensMesa[i].desc_item;
        String obs_item_atual = _listaItensMesa[i].obs_adici;
        int indice_encontrado = -1;
        for(int y = 0; y < _listaItensExistentesMesa.length; y++)
          {
            if(_listaItensExistentesMesa[y].desc_item == desc_item_atual && _listaItensExistentesMesa[y].obs_adici == obs_item_atual)
              {
                indice_encontrado = y;
              }
          }
        if(indice_encontrado != -1)
        {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
          ItemMesa _ja_existe = _listaItensExistentesMesa[indice_encontrado];
          int _indice = _listaItensExistentesMesa.indexOf(_ja_existe);
          num _novo_valor = _ja_existe.valor_tot + _listaItensMesa[i].valor_tot;
          int _nova_qtd = _ja_existe.qtd + _listaItensMesa[i].qtd;
          _ja_existe.valor_tot = _novo_valor;
          _ja_existe.qtd = _nova_qtd;
          _listaItensExistentesMesa[_indice] = _ja_existe;
        }
        else{
          _listaItensMesa[i].id_item = _ult_id_registrado + 1;
          _listaItensExistentesMesa.add(_listaItensMesa[i]);
        }
      }
    }
    else
      {
        for(int i = 0; i < _listaItensMesa.length; i++)
          {
            _listaItensMesa[i].id_item = _ult_id_registrado + 1 + i;
            _listaItensExistentesMesa.add(_listaItensMesa[i]);
          }
      }
    //limpar itens da mesa para atualizar na sequencia
    await FirebaseDatabase.instance.ref().child('itens-mesa').child(widget._numMesa.toString()).remove();
    //registramos os itens na mesa
    final ref = FirebaseDatabase.instance.ref("itens-mesa/" + widget._numMesa.toString());
    for(int i = 1; i <= _listaItensExistentesMesa.length; i++)
      {
        int _id_registrar = i;
        final json = _listaItensExistentesMesa[i-1].toJson();
        await ref.child(_id_registrar.toString()).set(json);
      }
    //excluimos o ultimo registro de impressao
    await FirebaseDatabase.instance.ref().child('imprimir').child(widget._numMesa.toString()).remove();
    //registramos os itens na tabela de reimpressão de ultimo pedido
    final ref1 = FirebaseDatabase.instance.ref("imprimir/" + widget._numMesa.toString());
    for(int i = 0; i <= _listaItensMesa.length; i++)
    {
      if(i == 0)
        {
          ItemMesa obs = ItemMesa();
          int _id_registrar = i;
          obs.desc_item = _controllerObsCozinha.text.toString();
          obs.id_item = 0;
          final json = obs.toJson();
          await ref1.child(_id_registrar.toString()).set(json);
        }
      else{
        int _id_registrar = i;
        final json = _listaItensMesa[i-1].toJson();
        await ref1.child(_id_registrar.toString()).set(json);
      }
    }
    //geramos um identificador para essa mesa, para auxiliar nos relatórios do sistema
    DateTime now = DateTime.now();
    String data = DateFormat('dd-MM-yyyy kk:mm:ss').format(now);
    String dma = data.substring(0, 10);
    String hms = data.substring(11, 19);
    String id_registro = "M-" + widget._numMesa.toString() + "-D-" + dma + "-H-" + hms;
    //registramos o total atual da mesa
    num _total_inserir_mesa = _calcula_total_inserir_mesa();
    if(_mesa_recuperada.total > 0) {
      _mesa_salvar.total = _mesa_recuperada.total + _total_inserir_mesa;
      _mesa_salvar.identificador = _mesa_recuperada.identificador;
    }
    else {
      _mesa_salvar.total = _total_inserir_mesa;
      _mesa_salvar.identificador = id_registro;
    }
    _mesa_salvar.status = 1;
    _mesa_salvar.numero = widget._numMesa;
    final json = _mesa_salvar.toJson();
    final ref_mesa = FirebaseDatabase.instance.ref("mesas/" + _mesa_salvar.numero.toString());
    await ref_mesa.set(json);
    //voltamos à tela das mesas
    Navigator.of(context).pop();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Mesas()
        )
    );
  }

  _registra_itens_balcao() async{
    mostrarDialogoSalvando();
    //geramos um identificador
    DateTime now = DateTime.now();
    String data = DateFormat('dd-MM-yyyy kk:mm:ss').format(now);
    String dma = data.substring(0, 10);
    String hms = data.substring(11, 19);
    String id_registro = "M-0-D-" + dma + "-H-" + hms;
    //registramos o total atual da mesa
    num _total_inserir_balcao = _calcula_total_inserir_mesa();
    //realizamos a impressão dos dados
    if(_param_imprimir == 0)
      _imprimir_pedido_balcao();
    //registro do pedido
    Pedido _novo_pedido = Pedido();
    if(_listaPedidos.length > 0)
      _novo_pedido.id_pedido = _listaPedidos.last.id_pedido + 1;
    else
      _novo_pedido.id_pedido = 1;
    _novo_pedido.tipo = 0;
    _novo_pedido.data = data;
    _novo_pedido.total = _total_inserir_balcao;
    _novo_pedido.identificador = id_registro;
    _novo_pedido.pagamento = _tipo_pagamento;
    _novo_pedido.nome_cliente = _blc_nome_cli;
    _novo_pedido.celular_cliente = _blc_celu_cli;
    _novo_pedido.endereco_cliente = "-";
    _novo_pedido.obs = _obs_cozinha;

    _listaItensExistentesMesa.clear();
    final refItemPedido = FirebaseDatabase.instance.ref();
    final snapshot1 = await refItemPedido.child("itens-pedido/" + id_registro.toString()).get();
    if (snapshot1.exists) {
      final json = snapshot1.value as List;
      for(DataSnapshot ds in snapshot1.children)
      {
        ItemMesa _itemLista = ItemMesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = ItemMesa.fromJson(json);
        _listaItensExistentesMesa.add(_itemLista);
      }
    }
    //verificação de id
    int _ult_id_registrado = 0;
    if(_listaItensExistentesMesa.length > 0)
      _ult_id_registrado = _listaItensExistentesMesa.last.id_item;

    //verificamos se já existem itens inseridos iguais aos que estão sendo inseridos para unir as quantidades e valores
    if(_listaItensExistentesMesa.length > 0)
    {
      for(int i = 0; i < _listaItensMesa.length; i++)
      {
        String desc_item_atual = _listaItensMesa[i].desc_item;
        String obs_item_atual = _listaItensMesa[i].obs_adici;
        int indice_encontrado = -1;
        for(int y = 0; y < _listaItensExistentesMesa.length; y++)
        {
          if(_listaItensExistentesMesa[y].desc_item == desc_item_atual && _listaItensExistentesMesa[y].obs_adici == obs_item_atual)
          {
            indice_encontrado = y;
          }
        }
        if(indice_encontrado != -1)
        {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
          ItemMesa _ja_existe = _listaItensExistentesMesa[indice_encontrado];
          int _indice = _listaItensExistentesMesa.indexOf(_ja_existe);
          num _novo_valor = _ja_existe.valor_tot + _listaItensMesa[i].valor_tot;
          int _nova_qtd = _ja_existe.qtd + _listaItensMesa[i].qtd;
          _ja_existe.valor_tot = _novo_valor;
          _ja_existe.qtd = _nova_qtd;
          _listaItensExistentesMesa[_indice] = _ja_existe;
        }
        else{
          _listaItensMesa[i].id_item = _ult_id_registrado + 1;
          _listaItensExistentesMesa.add(_listaItensMesa[i]);
        }
      }
    }
    else
    {
      for(int i = 0; i < _listaItensMesa.length; i++)
      {
        _listaItensMesa[i].id_item = _ult_id_registrado + 1 + i;
        _listaItensExistentesMesa.add(_listaItensMesa[i]);
      }
    }
    //limpar itens da mesa para atualizar na sequencia
    await FirebaseDatabase.instance.ref().child('itens-pedido').child(id_registro.toString()).remove();
    //registramos os itens na mesa
    final ref = FirebaseDatabase.instance.ref("itens-pedido/" + id_registro.toString());
    for(int i = 1; i <= _listaItensExistentesMesa.length; i++)
    {
      int _id_registrar = i;
      final json = _listaItensExistentesMesa[i-1].toJson();
      await ref.child(_id_registrar.toString()).set(json);
    }
    //salvamos o pedido
    final json = _novo_pedido.toJson();
    final ref_balc = FirebaseDatabase.instance.ref('pedidos/' + _novo_pedido.id_pedido.toString());
    await ref_balc.set(json);
    //voltamos à tela das mesas
    Navigator.of(context).pop();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Mesas()
        )
    );
  }

  _atualiza_itens_balcao(Pedido pedido_alterar) async{
    mostrarDialogoSalvando();
    //verificação de id
    int _ult_id_registrado = 0;
    if(_listaItensExistentesPedido.length > 0)
      _ult_id_registrado = _listaItensExistentesPedido.last.id_item;
    //verificamos se já existem itens inseridos iguais aos que estão sendo inseridos para unir as quantidades e valores
    if(_listaItensExistentesPedido.length > 0)
    {
      for(int i = 0; i < _listaItensMesa.length; i++)
      {
        String desc_item_atual = _listaItensMesa[i].desc_item;
        String obs_item_atual = _listaItensMesa[i].obs_adici;
        int indice_encontrado = -1;
        for(int y = 0; y < _listaItensExistentesPedido.length; y++)
        {
          if(_listaItensExistentesPedido[y].desc_item == desc_item_atual && _listaItensExistentesPedido[y].obs_adici == obs_item_atual)
          {
            indice_encontrado = y;
          }
        }
        if(indice_encontrado != -1)
        {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
          ItemMesa _ja_existe = _listaItensExistentesPedido[indice_encontrado];
          int _indice = _listaItensExistentesPedido.indexOf(_ja_existe);
          num _novo_valor = _ja_existe.valor_tot + _listaItensMesa[i].valor_tot;
          int _nova_qtd = _ja_existe.qtd + _listaItensMesa[i].qtd;
          _ja_existe.valor_tot = _novo_valor;
          _ja_existe.qtd = _nova_qtd;
          _listaItensExistentesPedido[_indice] = _ja_existe;
        }
        else{
          _listaItensMesa[i].id_item = _ult_id_registrado + 1;
          _listaItensExistentesPedido.add(_listaItensMesa[i]);
        }
      }
    }
    else
    {
      for(int i = 0; i < _listaItensMesa.length; i++)
      {
        _listaItensMesa[i].id_item = _ult_id_registrado + 1 + i;
        _listaItensExistentesPedido.add(_listaItensMesa[i]);
      }
    }
    //realizamos a impressão dos dados
    _imprimir_pedido_balcao_alterar(pedido_alterar);
    //limpar itens da mesa para atualizar na sequencia
    await FirebaseDatabase.instance.ref().child('itens-pedido').child(widget._identificador_pedido.toString()).remove();
    //registramos os itens na mesa
    final ref = FirebaseDatabase.instance.ref("itens-pedido/" + widget._identificador_pedido.toString());
    for(int i = 1; i <= _listaItensExistentesPedido.length; i++)
    {
      int _id_registrar = i;
      final json = _listaItensExistentesPedido[i-1].toJson();
      await ref.child(_id_registrar.toString()).set(json);
    }
    //atualizamos o total atual do pedido
    num _total_atualizar_pedido = _calcula_total_itens_existentes_pedido();
    final ref1 = FirebaseDatabase.instance.ref("pedidos/" + pedido_alterar.id_pedido.toString());
    await ref1.child("total").set(_total_atualizar_pedido);
    //voltamos à tela das mesas
    Navigator.of(context).pop();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Mesas()
        )
    );
  }

  _registra_itens_entrega() async{
    mostrarDialogoSalvando();
    //nova entrega
    Entrega _nova_ent = Entrega();
    _nova_ent.total = _calcula_total_inserir_mesa() + _valor_taxa;
    _nova_ent.taxa = _valor_taxa;
    _nova_ent.pagamento = _tipo_pagamento;
    //geramos um identificador para essa mesa, para auxiliar nos relatórios do sistema
    DateTime now = DateTime.now();
    String data = DateFormat('dd-MM-yyyy kk:mm:ss').format(now);
    String dma = data.substring(0, 10);
    String hms = data.substring(11, 19);
    String id_registro = "M-0-D-" + dma + "-H-" + hms;
    _nova_ent.cliente = id_registro;
    //registramos o total atual da mesa
    num _total_inserir_entrega = _calcula_total_inserir_mesa() + _valor_taxa;
    //realizamos a impressão dos dados
    if(_param_imprimir == 0)
      _imprimir_pedido_entrega();
    //endereço do cliente
    String _endereco_salvar = _ctlRua.text.toString() + "\nN " + _ctlNumero.text.toString() + "\n" + _ctlBairro.text.toString() + "\n" + _ctlRef.text.toString();
    //registro do pedido
    Pedido _novo_pedido = Pedido();
    if(_listaPedidos.length > 0)
      _novo_pedido.id_pedido = _listaPedidos.last.id_pedido + 1;
    else
      _novo_pedido.id_pedido = 1;
    _novo_pedido.tipo = 1;
    _novo_pedido.data = data;
    _novo_pedido.total = _total_inserir_entrega;
    _novo_pedido.identificador = id_registro;
    _novo_pedido.pagamento = _tipo_pagamento;
    _novo_pedido.nome_cliente = _ent_nome_cli;
    _novo_pedido.celular_cliente = _ent_celu_cli;
    _novo_pedido.endereco_cliente = _endereco_salvar;
    _novo_pedido.obs = _obs_cozinha;

    _listaItensExistentesMesa.clear();
    final refItemPedido = FirebaseDatabase.instance.ref();
    final snapshot1 = await refItemPedido.child("itens-pedido/" + id_registro.toString()).get();
    if (snapshot1.exists) {
      final json = snapshot1.value as List;
      for(DataSnapshot ds in snapshot1.children)
      {
        ItemMesa _itemLista = ItemMesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = ItemMesa.fromJson(json);
        _listaItensExistentesMesa.add(_itemLista);
      }
    }
    //verificação de id
    int _ult_id_registrado = 0;
    if(_listaItensExistentesMesa.length > 0)
      _ult_id_registrado = _listaItensExistentesMesa.last.id_item;

    //verificamos se já existem itens inseridos iguais aos que estão sendo inseridos para unir as quantidades e valores
    if(_listaItensExistentesMesa.length > 0)
    {
      for(int i = 0; i < _listaItensMesa.length; i++)
      {
        String desc_item_atual = _listaItensMesa[i].desc_item;
        String obs_item_atual = _listaItensMesa[i].obs_adici;
        int indice_encontrado = -1;
        for(int y = 0; y < _listaItensExistentesMesa.length; y++)
        {
          if(_listaItensExistentesMesa[y].desc_item == desc_item_atual && _listaItensExistentesMesa[y].obs_adici == obs_item_atual)
          {
            indice_encontrado = y;
          }
        }
        if(indice_encontrado != -1)
        {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
          ItemMesa _ja_existe = _listaItensExistentesMesa[indice_encontrado];
          int _indice = _listaItensExistentesMesa.indexOf(_ja_existe);
          num _novo_valor = _ja_existe.valor_tot + _listaItensMesa[i].valor_tot;
          int _nova_qtd = _ja_existe.qtd + _listaItensMesa[i].qtd;
          _ja_existe.valor_tot = _novo_valor;
          _ja_existe.qtd = _nova_qtd;
          _listaItensExistentesMesa[_indice] = _ja_existe;
        }
        else{
          _listaItensMesa[i].id_item = _ult_id_registrado + 1;
          _listaItensExistentesMesa.add(_listaItensMesa[i]);
        }
      }
    }
    else
    {
      for(int i = 0; i < _listaItensMesa.length; i++)
      {
        _listaItensMesa[i].id_item = _ult_id_registrado + 1 + i;
        _listaItensExistentesMesa.add(_listaItensMesa[i]);
      }
    }
    //limpar itens da mesa para atualizar na sequencia
    await FirebaseDatabase.instance.ref().child('itens-pedido').child(id_registro.toString()).remove();
    //registramos os itens na mesa
    final ref = FirebaseDatabase.instance.ref("itens-pedido/" + id_registro.toString());
    for(int i = 1; i <= _listaItensExistentesMesa.length; i++)
    {
      int _id_registrar = i;
      final json = _listaItensExistentesMesa[i-1].toJson();
      await ref.child(_id_registrar.toString()).set(json);
    }
    //salvamos o pedido
    final json = _novo_pedido.toJson();
    final ref_balc = FirebaseDatabase.instance.ref('pedidos/' + _novo_pedido.id_pedido.toString());
    await ref_balc.set(json);
    //voltamos à tela das mesas
    Navigator.of(context).pop();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Mesas()
        )
    );
  }

  _atualiza_itens_entrega(Pedido pedido_alterar) async{
    mostrarDialogoSalvando();
    //verificação de id
    int _ult_id_registrado = 0;
    if(_listaItensExistentesPedido.length > 0)
      _ult_id_registrado = _listaItensExistentesPedido.last.id_item;
    //verificamos se já existem itens inseridos iguais aos que estão sendo inseridos para unir as quantidades e valores
    if(_listaItensExistentesPedido.length > 0)
    {
      for(int i = 0; i < _listaItensMesa.length; i++)
      {
        String desc_item_atual = _listaItensMesa[i].desc_item;
        String obs_item_atual = _listaItensMesa[i].obs_adici;
        int indice_encontrado = -1;
        for(int y = 0; y < _listaItensExistentesPedido.length; y++)
        {
          if(_listaItensExistentesPedido[y].desc_item == desc_item_atual && _listaItensExistentesPedido[y].obs_adici == obs_item_atual)
          {
            indice_encontrado = y;
          }
        }
        if(indice_encontrado != -1)
        {//o item que está sendo inserido já existe na lista, portanto, somamos sua quantidade e valor ao já existente
          ItemMesa _ja_existe = _listaItensExistentesPedido[indice_encontrado];
          int _indice = _listaItensExistentesPedido.indexOf(_ja_existe);
          num _novo_valor = _ja_existe.valor_tot + _listaItensMesa[i].valor_tot;
          int _nova_qtd = _ja_existe.qtd + _listaItensMesa[i].qtd;
          _ja_existe.valor_tot = _novo_valor;
          _ja_existe.qtd = _nova_qtd;
          _listaItensExistentesPedido[_indice] = _ja_existe;
        }
        else{
          _listaItensMesa[i].id_item = _ult_id_registrado + 1;
          _listaItensExistentesPedido.add(_listaItensMesa[i]);
        }
      }
    }
    else
    {
      for(int i = 0; i < _listaItensMesa.length; i++)
      {
        _listaItensMesa[i].id_item = _ult_id_registrado + 1 + i;
        _listaItensExistentesPedido.add(_listaItensMesa[i]);
      }
    }
    num _total_atualizar_pedido = _calcula_total_itens_existentes_pedido() + _taxa_atualizar_pedido;
    pedido_alterar.total = _total_atualizar_pedido;
    //realizamos a impressão dos dados
    _imprimir_pedido_entrega_alterar(pedido_alterar);
    //limpar itens da mesa para atualizar na sequencia
    await FirebaseDatabase.instance.ref().child('itens-pedido').child(widget._identificador_pedido.toString()).remove();
    //registramos os itens na mesa
    final ref = FirebaseDatabase.instance.ref("itens-pedido/" + widget._identificador_pedido.toString());
    for(int i = 1; i <= _listaItensExistentesPedido.length; i++)
    {
      int _id_registrar = i;
      final json = _listaItensExistentesPedido[i-1].toJson();
      await ref.child(_id_registrar.toString()).set(json);
    }
    //atualizamos o total atual do pedido
    final ref1 = FirebaseDatabase.instance.ref("pedidos/" + pedido_alterar.id_pedido.toString());
    await ref1.child("total").set(_total_atualizar_pedido);
    //voltamos à tela das mesas
    Navigator.of(context).pop();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Mesas()
        )
    );
  }

  _recupera_itens_mesa_existentes() async
  {
    _listaItensExistentesMesa.clear();
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("itens-mesa/" + widget._numMesa.toString()).get();
    if (snapshot.exists) {
      for(DataSnapshot ds in snapshot.children)
      {
        final json = ds.value as Map<dynamic, dynamic>;
        ItemMesa _item_recuperado = ItemMesa.fromJson(json);
        _listaItensExistentesMesa.add(_item_recuperado);
      }
    }
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

  num _calcula_total_itens_existentes_pedido()
  {
    num _total_inserir_mesa = 0;
    for(ItemMesa it in _listaItensExistentesPedido)
    {
      _total_inserir_mesa = _total_inserir_mesa + it.valor_tot;
    }
    return _total_inserir_mesa;
  }

  num _calcula_valor_taxa_reimprimir(num total)
  {
    num _total_itens = _calcula_total_itens_existentes_pedido();
    num _taxa = total - _total_itens;
    return _taxa;
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
                                style: TextStyle(color: cores.corMarromSF),
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

  _imprimir_pedido() async
  {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(widget._ip_imp.toString(), port: 9100); //10.253.0.98

    if (res == PosPrintResult.success) {
      //verificar a qtd de vias para imprimir
      for(int i = 0; i < widget._qtd_vias; i++)
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

    //Cabeçalho da impressão
    printer.text("Mesa " + widget._numMesa.toString(),
        styles: PosStyles(
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.center
        ));
    printer.text("Hora: " + data,
        styles: PosStyles(
            align: PosAlign.center
        ));
    printer.text("Garcom: " + _remove_diacritics(widget._garcom.toString()),
        styles: PosStyles(
            align: PosAlign.center
        ));
    if(!_obs_cozinha.isEmpty && _obs_cozinha != "")
      {
        printer.text("Obs.: " + _obs_cozinha.toString(),
            styles: PosStyles(
                height: PosTextSize.size1,
                width: PosTextSize.size1,
                align: PosAlign.center,
                bold: true
            ));
      }
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
      /*PosColumn(
        text: 'VALOR',
        width: 3,
        styles: PosStyles(align: PosAlign.right, underline: true, bold: true),
      ),*/
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
    printer.text("Powered by SSoft",
        styles: PosStyles(
            align: PosAlign.center
        ));

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
  //impressao de balcao
  _imprimir_pedido_balcao() async
  {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(widget._ip_imp.toString(), port: 9100); //10.253.0.98

    if (res == PosPrintResult.success) {
      _gerar_impressao_balcao(printer);
      printer.disconnect();
    }

    print('Print result: ${res.msg}');
  }

  Future<void> _gerar_impressao_balcao(NetworkPrinter printer) async {

    DateTime now = DateTime.now();
    String data = DateFormat('kk:mm:ss').format(now);
    String forma_pag = "";

    if(_tipo_pagamento == 0)
      forma_pag = "DINHEIRO";
    if(_tipo_pagamento == 1)
      forma_pag = "CARTAO";
    if(_tipo_pagamento == 2)
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
    printer.text(_blc_nome_cli, styles: PosStyles(bold: true,align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2));
    printer.text(_blc_celu_cli, styles: PosStyles(bold: true,align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2));
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
    _valor_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_inserir_mesa());
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
    if(!_obs_cozinha.isEmpty && _obs_cozinha != "")
    {
      printer.text("Obs.: " + _obs_cozinha.toString(),
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

  _imprimir_pedido_balcao_alterar(Pedido pedido_alterar) async
  {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(widget._ip_imp.toString(), port: 9100); //10.253.0.98

    if (res == PosPrintResult.success) {
      _gerar_impressao_balcao_alterar(printer, pedido_alterar);
      printer.disconnect();
    }

    print('Print result: ${res.msg}');
  }

  Future<void> _gerar_impressao_balcao_alterar(NetworkPrinter printer, Pedido pedido_alterar) async {

    String data = pedido_alterar.data.substring(11, 19);
    String forma_pag = "";

    if(pedido_alterar.pagamento == 0)
      forma_pag = "DINHEIRO";
    if(pedido_alterar.pagamento == 1)
      forma_pag = "CARTAO";
    if(pedido_alterar.pagamento == 2)
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
    printer.text(pedido_alterar.nome_cliente, styles: PosStyles(bold: true,align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2));
    printer.text(pedido_alterar.celular_cliente, styles: PosStyles(bold: true,align: PosAlign.left, height: PosTextSize.size2, width: PosTextSize.size2));
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
    for(int i = 0; i < _listaItensExistentesPedido.length; i++)
    {
      _parametro_num_char = 0;
      String item_desc = _remove_diacritics(_listaItensExistentesPedido[i].desc_item);
      String item_mostrar = item_desc;
      if(item_desc.length > 19){
        _linha1 = item_desc.substring(0, 19);
        _linha2 = item_desc.substring(19, item_desc.length);
        _parametro_num_char = 1;

        printer.row([
          PosColumn(
            text: _listaItensExistentesPedido[i].qtd.toString(),
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
            text: _listaItensExistentesPedido[i].qtd.toString(),
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
      if(!_listaItensExistentesPedido[i].obs_adici.isEmpty && _listaItensExistentesPedido[i].obs_adici != "")
      {
        printer.row([
          PosColumn(
            text: "",
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: _remove_diacritics(_listaItensExistentesPedido[i].obs_adici).replaceAll("\n", ", "),
            width: 11,
            styles: PosStyles(align: PosAlign.left, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
        ]);
      }
      printer.text("----------------------------------------");
    }
    String _valor_mostrar = "";
    _valor_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_inserir_mesa());
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
    if(!pedido_alterar.obs.isEmpty && pedido_alterar.obs != "")
    {
      printer.text("Obs.: " + pedido_alterar.obs.toString(),
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

  //impressao de entrega
  _imprimir_pedido_entrega() async
  {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(widget._ip_imp.toString(), port: 9100); //10.253.0.98

    if (res == PosPrintResult.success) {
      //verificar a qtd de vias para imprimir
      for(int i = 0; i < 2; i++)
      {
        _gerar_impressao_entrega(printer);
      }
      printer.disconnect();
    }

    print('Print result: ${res.msg}');
  }

  Future<void> _gerar_impressao_entrega(NetworkPrinter printer) async {

    DateTime now = DateTime.now();
    String data = DateFormat('kk:mm:ss').format(now);
    String forma_pag = "";

    if(_tipo_pagamento == 0)
      forma_pag = "DINHEIRO";
    if(_tipo_pagamento == 1)
      forma_pag = "CARTAO";
    if(_tipo_pagamento == 2)
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
    printer.text(_ent_nome_cli, styles: PosStyles(bold: true,align: PosAlign.left));
    printer.text(_ent_celu_cli, styles: PosStyles(bold: true,align: PosAlign.left));
    printer.text(_ent_rua_cli, styles: PosStyles(bold: true,align: PosAlign.left));
    printer.text("N " + _ent_nume_cli, styles: PosStyles(bold: true,align: PosAlign.left));
    printer.text(_ent_bair_cli, styles: PosStyles(bold: true,align: PosAlign.left));
    printer.text(_ent_refe_cli, styles: PosStyles(bold: true,align: PosAlign.left));
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
    _valor_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_inserir_mesa() + _valor_taxa);
    _valor_taxa_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(_valor_taxa);
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
    if(!_obs_cozinha.isEmpty && _obs_cozinha != "")
    {
      printer.text("Obs.: " + _obs_cozinha.toString(),
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

  _imprimir_pedido_entrega_alterar(Pedido pedido_alterar) async
  {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(widget._ip_imp.toString(), port: 9100); //10.253.0.98

    if (res == PosPrintResult.success) {
      _gerar_impressao_entrega_alterar(printer, pedido_alterar);
      printer.disconnect();
    }

    print('Print result: ${res.msg}');
  }

  Future<void> _gerar_impressao_entrega_alterar(NetworkPrinter printer, Pedido dados_pedido) async {

    String data = dados_pedido.data.substring(11, 19);
    String forma_pag = "";

    if(_tipo_pagamento == 0)
      forma_pag = "DINHEIRO";
    if(_tipo_pagamento == 1)
      forma_pag = "CARTAO";
    if(_tipo_pagamento == 2)
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
    for(int i = 0; i < _listaItensExistentesPedido.length; i++)
    {
      _parametro_num_char = 0;
      String item_desc = _remove_diacritics(_listaItensExistentesPedido[i].desc_item);
      String item_mostrar = item_desc;
      if(item_desc.length > 19){
        _linha1 = item_desc.substring(0, 19);
        _linha2 = item_desc.substring(19, item_desc.length);
        _parametro_num_char = 1;

        printer.row([
          PosColumn(
            text: _listaItensExistentesPedido[i].qtd.toString(),
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
            text: _listaItensExistentesPedido[i].qtd.toString(),
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          ),
          PosColumn(
            text: item_mostrar,
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
      if(!_listaItensExistentesPedido[i].obs_adici.isEmpty && _listaItensExistentesPedido[i].obs_adici != "")
      {
        printer.row([
          PosColumn(
            text: "",
            width: 1,
            styles: PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: _remove_diacritics(_listaItensExistentesPedido[i].obs_adici).replaceAll("\n", ", "),
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
    _valor_taxa_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_valor_taxa_reimprimir(dados_pedido.total));
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
}
