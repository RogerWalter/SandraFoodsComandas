import 'package:comandas_app/model/Mesa.dart';
import 'package:comandas_app/model/Entrega.dart';
import 'package:comandas_app/model/Comanda.dart';
import 'package:comandas_app/model/ItemComanda.dart';
import 'package:comandas_app/model/Pedido.dart';
import 'package:comandas_app/model/ItemMesa.dart';
import 'package:comandas_app/tela/Visualizar.dart';
import 'package:comandas_app/tela/Fechar.dart';
import 'package:comandas_app/model/Parametro.dart';
import 'package:comandas_app/res/CustomColors.dart';
import 'package:comandas_app/tela/Adicionar.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:auto_size_text_pk/auto_size_text_pk.dart';
import 'dart:typed_data';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Mesas()
  ));
}

class Mesas extends StatefulWidget {
  const Mesas({Key? key}) : super(key: key);

  @override
  _MesasState createState() => _MesasState();
}

class _MesasState extends State<Mesas> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _verificarParametros();
  }
  Color _corLaranjaSF = const Color(0xffff6900);
  Color _corPastelSF = const Color(0xffFAFCC2);
  Color _corMarromSF = const Color(0xff3d2314);

  Parametro _parametros = Parametro();
  int _parametro_qtd_mesas_antigo = 0;
  TextEditingController _controllerNome = TextEditingController();
  TextEditingController _controllerQtdMesas = TextEditingController();
  TextEditingController _controllerQtdColunas = TextEditingController();
  TextEditingController _controllerQtdVias = TextEditingController();
  TextEditingController _controllerIpImp = TextEditingController();
  bool _visibility = false;

  int _parametro_tipo_adicionar = -1; //0 = MESA | 1 = ENTREGA | 2 = BALCÃO | 3 = ENTREGA (editar)  | 4 = BALCÃO (editar)

  final List <Mesa> _listaMesas = [];
  final List <Pedido> _listaPedidos = [];
  final List <ItemMesa> _listaItensMesa = [];
  final List <ItemComanda> _listaItensMesaTotalRelatorio = [];

  _carregaDadosMesas(String _nome, int _qtd){
    setState(() {
      build(context);
      _parametros.nome_garcom = _nome;
      _parametros.qtd_colunas = _qtd;
      _visibility = true;
    });
  }

  _salvarParametros(int _parametro_primeiro_acesso) async{
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("nome", _parametros.nome_garcom);
    prefs.setInt("coluna", _parametros.qtd_colunas);

    final json = _parametros.toJson();
    final ref = FirebaseDatabase.instance.ref("parametros/");
    await ref.set(json);
    if(_parametro_primeiro_acesso == 1)
      _salvarMesaFirebase(_parametros.qtd_mesas);
  }

  _verificarParametros() async{
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("parametros").get();
    final prefs = await SharedPreferences.getInstance();
    if(prefs.getString("nome") != null && prefs.getString("nome") != "")
      {
        String nome_garcom_recuperado = prefs.getString("nome").toString();
        int qtd_colunas_recuperada = int.parse(prefs.getInt("coluna").toString());
        if (snapshot.exists) {//Ja foi acessado o app antes, já existe parametrização
          final json = snapshot.value as Map<dynamic, dynamic>;
          _parametros = Parametro.fromJson(json);
          _recupera_infos_mesas_existentes(nome_garcom_recuperado, qtd_colunas_recuperada);
        } else {//app nunca foi acessado. Necessário abrir tela para definição de parâmetros
          mostrarDialogoParametros();
        }
      }
    else
      {
        mostrarDialogoParametros();
      }
  }

  _salvarMesaFirebase(int _qtd_mesas) async{
    await Firebase.initializeApp();

    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("mesas").get();
    if (snapshot.exists) {
      _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
    }
    else{
      for(int i = 1; i <=_qtd_mesas; i++ )
      {
        Mesa _mesa = Mesa();
        _mesa.numero = i;
        _mesa.status = 0;
        _mesa.total = 0;
        _mesa.identificador = "";
        final json = _mesa.toJson();
        final ref = FirebaseDatabase.instance.ref("mesas/" + i.toString());
        await ref.set(json);
      }
      _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
    }
  }
  _recuperarPedidos(String _nome, int _qtd) async{
    _listaPedidos.clear();
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
    _carregaDadosMesas(_nome, _qtd);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 2,
      child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Color(0xff3d2314),
            title: const Text('Mesas e Comandas', style: TextStyle(color: Colors.white)),
            actions: <Widget>[
              IconButton(
                icon: const Icon
                  (Icons.build, color: Color(0xffff6900),),
                tooltip: 'Configurações',
                onPressed: () {
                  setState(() {
                    mostrarDialogoParametros();
                  });
                },
              ),
            ],
            bottom: TabBar(
              indicatorColor: Color(0xffff6900),
              tabs: <Widget>[
                Tab(
                  icon: Icon(Icons.table_bar, color: Colors.white,)
                ),
                Tab(
                  icon: Icon(Icons.receipt_long_outlined, color: Colors.white,)
                )
              ],
            ),
          ),
          backgroundColor: Colors.white,
          body: TabBarView(
            children: <Widget>[
              Stack(//tab mesas
                  children: <Widget>[
                    Visibility(
                        visible: !_visibility,
                        child: Container(
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              strokeWidth: 10,
                              backgroundColor: CustomColors().corMarromSF,
                              valueColor: AlwaysStoppedAnimation<Color> (CustomColors().corLaranjaSF),
                            )
                        )
                    ),

                    Visibility(
                        visible: _visibility,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                                child: ScrollConfiguration(
                                    behavior: ScrollBehavior(),
                                    child: GlowingOverscrollIndicator(
                                      axisDirection: AxisDirection.down,
                                      color: _corLaranjaSF.withOpacity(0.20),
                                      child: GridView.count(
                                        scrollDirection: Axis.vertical,
                                        shrinkWrap: true,
                                        crossAxisCount: _parametros.qtd_colunas,
                                        mainAxisSpacing: (16/_parametros.qtd_colunas),
                                        crossAxisSpacing: (16/_parametros.qtd_colunas),
                                        children: List.generate(_listaMesas.length, (index) {
                                          return Card(
                                              elevation: 4,
                                              child: InkWell(
                                                  splashColor: _corLaranjaSF.withOpacity(0.20),

                                                  onTap: (){
                                                    mostrarDialogoMesa(index + 1, _listaMesas[index].total, _listaMesas[index].identificador);
                                                  },
                                                  child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.transparent,
                                                        border: Border.all(
                                                            color: (_listaMesas.length > 0 && _listaMesas[index].status == 1) ? _corLaranjaSF : _corMarromSF,
                                                            width: 6
                                                        ),
                                                        borderRadius: BorderRadius.all(Radius.circular(5)),
                                                      ),
                                                      margin: EdgeInsets.all(8),
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                        children: <Widget>[
                                                          Text(
                                                            "Mesa " + _listaMesas[index].numero.toString(),
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(
                                                              color: _corMarromSF,
                                                              fontSize: (48/_parametros.qtd_colunas),
                                                            ),
                                                          ),
                                                          Text(
                                                            "Total:\n" + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaMesas[index].total),
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(
                                                                color: Colors.deepOrange,
                                                                fontSize: (40/_parametros.qtd_colunas),
                                                                fontWeight: FontWeight.w700
                                                            ),
                                                          )
                                                        ],
                                                      )
                                                  )
                                              )
                                          );
                                        }),
                                      ),
                                    )
                                )
                            )
                          ],
                        )
                    )
                  ]
              ),
              Stack(//tab pedidos
                children: <Widget>[
                  Visibility(
                      visible: _visibility,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
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
                                            //abrimos a tela de adicionar itens para o balcão
                                            _parametro_tipo_adicionar = 2;
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) => Adicionar(0, _parametros.nome_garcom, _parametros.ip_impressora, _parametros.qtd_vias_imprimir, _parametro_tipo_adicionar, "")
                                                )
                                            );
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          elevation: 4,
                                          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                          primary: _corMarromSF,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text("Balcão", style: TextStyle(color: _corLaranjaSF, fontSize: 16, fontWeight: FontWeight.w900),)
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
                                          _parametro_tipo_adicionar = 1;
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) => Adicionar(0, _parametros.nome_garcom, _parametros.ip_impressora, _parametros.qtd_vias_imprimir, _parametro_tipo_adicionar, "")
                                              )
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          elevation: 4,
                                          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                          primary: _corMarromSF,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text("Entrega", style: TextStyle(color: _corLaranjaSF, fontSize: 16, fontWeight: FontWeight.w900),)
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                          Expanded(
                              child: ScrollConfiguration(
                                  behavior: ScrollBehavior(),
                                  child: GlowingOverscrollIndicator(
                                    axisDirection: AxisDirection.down,
                                    color: _corLaranjaSF.withOpacity(0.20),
                                    child: GridView.count(
                                      scrollDirection: Axis.vertical,
                                      shrinkWrap: true,
                                      crossAxisCount: _parametros.qtd_colunas,
                                      mainAxisSpacing: (16/_parametros.qtd_colunas),
                                      crossAxisSpacing: (16/_parametros.qtd_colunas),
                                      children: List.generate(_listaPedidos.length, (index) {
                                        return Card(
                                            elevation: 4,
                                            child: InkWell(
                                                splashColor: _corLaranjaSF.withOpacity(0.20),
                                                onTap: (){
                                                  mostrarDialogoPedido(_listaPedidos[index]);
                                                },
                                                child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.transparent,
                                                      border: Border.all(
                                                          color: _corPastelSF,
                                                          width: 6
                                                      ),
                                                      borderRadius: BorderRadius.all(Radius.circular(5)),
                                                    ),
                                                    margin: EdgeInsets.all(8),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                      children: <Widget>[
                                                        AutoSizeText(
                                                          _listaPedidos[index].nome_cliente.toString(),
                                                          style: TextStyle(fontSize: 24),
                                                          maxLines: 1,
                                                          minFontSize: 12,
                                                          overflow: TextOverflow.ellipsis,
                                                          //overflowReplacement: Text("exagerou"),
                                                          //stepGranularity: 10,
                                                          //presetFontSizes: [30,20,10],
                                                        ),
                                                        Text(
                                                          _listaPedidos[index].tipo == 0 ? "Balcão" : "Entrega",
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            color: _corMarromSF,
                                                            fontSize: (48/_parametros.qtd_colunas),
                                                          ),
                                                        ),
                                                        Text(
                                                          "Total:\n" + NumberFormat.simpleCurrency(locale: 'pt_BR').format(_listaPedidos[index].total),
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                              color: Colors.deepOrange,
                                                              fontSize: (40/_parametros.qtd_colunas),
                                                              fontWeight: FontWeight.w700
                                                          ),
                                                        )
                                                      ],
                                                    )
                                                )
                                            )
                                        );
                                      }),
                                    ),
                                  )
                              )
                          )
                        ],
                      )
                  )
                ],
              )
            ],
          )
        )
      );
  }

  mostrarDialogoMesa(int numMesa, num total, String identificador)
  {
    showDialog(
      context: context,
      barrierDismissible: true,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Text('Mesa '+ numMesa.toString(), style: TextStyle(color: Color(0xffff6900), fontSize: 28, fontWeight: FontWeight.w800),),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                              height: 50,
                              width: 170,
                              child: Expanded(
                                child: ElevatedButton(
                                    onPressed: (){
                                      _parametro_tipo_adicionar = 0;
                                      Navigator.of(context).pop();
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => Adicionar(numMesa, _parametros.nome_garcom, _parametros.ip_impressora, _parametros.qtd_vias_imprimir, _parametro_tipo_adicionar, "")
                                          )
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(0, 0, 4, 0),
                                      primary: Color(0xff3d2314),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  child: Row(
                                    children: <Widget>[
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                        child: Icon(
                                          Icons.add,
                                          color: _corLaranjaSF,
                                          size: 30,
                                        ),
                                      ),
                                      Text("Adicionar Itens", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                    ],
                                  ),),
                              )
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                                height: 50,
                                width: 170,
                                child: Expanded(
                                  child: ElevatedButton(
                                    onPressed: (){
                                      if(total <= 0)
                                      {
                                        final snackBar = SnackBar(
                                          content: const Text('A mesa não possui itens', style: TextStyle(color: Colors.white),),
                                          backgroundColor: _corLaranjaSF,
                                          duration: Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Ok',
                                            textColor: _corMarromSF,
                                            onPressed: () {
                                              // Some code to undo the change.
                                            },
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                      else{
                                        _recuperar_itens_reimprimir(numMesa);
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      primary: _corMarromSF,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                          child: Icon(
                                            Icons.print,
                                            color: _corLaranjaSF,
                                            size: 30,
                                          ),
                                        ),
                                        Text("Reimprimir Itens", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                      ],
                                    ),
                                  ),
                                )
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                              height: 50,
                              width: 170,
                              child: Expanded(
                                child: ElevatedButton(
                                    onPressed: (){
                                      if(total <= 0)
                                      {
                                        final snackBar = SnackBar(
                                          content: const Text('A mesa não possui itens', style: TextStyle(color: Colors.white),),
                                          backgroundColor: _corLaranjaSF,
                                          duration: Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Ok',
                                            textColor: _corMarromSF,
                                            onPressed: () {
                                              // Some code to undo the change.
                                            },
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                      else{
                                        Navigator.of(context).pop();
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => Visualizar(numMesa, "", _parametros.qtd_vias_imprimir, _parametros.ip_impressora)
                                            )
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      primary: _corMarromSF,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  child: Row(
                                    children: <Widget>[
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                        child: Icon(
                                          Icons.edit,
                                          color: _corLaranjaSF,
                                          size: 30,
                                        ),
                                      ),
                                      Text("Itens da Mesa", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                    ],
                                  ),
                                ),
                              )
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                              height: 50,
                              width: 170,
                              child: Expanded(
                                child: ElevatedButton(
                                    onPressed: (){
                                      if(total <= 0)
                                      {
                                        final snackBar = SnackBar(
                                          content: const Text('A mesa não possui itens', style: TextStyle(color: Colors.white),),
                                          backgroundColor: _corLaranjaSF,
                                          duration: Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Ok',
                                            textColor: _corMarromSF,
                                            onPressed: () {
                                              // Some code to undo the change.
                                            },
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                      else{
                                        Navigator.of(context).pop();
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => Fechar(numMesa, total, _parametros.ip_impressora, _parametros.qtd_vias_imprimir, identificador)
                                            )
                                        )
                                        .then((value) => {
                                          this.setState(() {
                                            _visibility = false;
                                            _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
                                            })
                                          });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      primary: _corMarromSF,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  child: Row(
                                    children: <Widget>[
                                      Padding(
                                          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                          child: Icon(
                                            Icons.monetization_on_outlined,
                                            color: _corLaranjaSF,
                                            size: 30,
                                          ),
                                      ),
                                      Text("Fechar Conta", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                    ],
                                  ),
                                ),
                              )
                            ),
                          ),
                          TextButton(onPressed: () {
                            Navigator.of(context).pop();
                          },
                              child: Text('Sair', style: TextStyle(color: _corMarromSF, fontSize: 16.0),))
                        ],
                      ),
                    ),
                  ),
                ),
                onWillPop: () async => true
            )
        ),
      ),
    );
  }

  mostrarDialogoPedido(Pedido pedido_selecionado)
  {
    showDialog(
      context: context,
      barrierDismissible: true,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: AutoSizeText(
                              'Pedido de '+ pedido_selecionado.nome_cliente.toString(),
                              style: TextStyle(fontSize: 24, color: _corLaranjaSF),
                              maxLines: 1,
                              minFontSize: 12,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                                height: 50,
                                width: 170,
                                child: Expanded(
                                  child: ElevatedButton(
                                    onPressed: (){
                                      if(pedido_selecionado.tipo == 0)
                                        _parametro_tipo_adicionar = 4;
                                      else
                                        _parametro_tipo_adicionar = 3;
                                      Navigator.of(context).pop();
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => Adicionar(0, _parametros.nome_garcom, _parametros.ip_impressora, _parametros.qtd_vias_imprimir, _parametro_tipo_adicionar, pedido_selecionado.identificador)
                                          )
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(0, 0, 4, 0),
                                      primary: Color(0xff3d2314),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                          child: Icon(
                                            Icons.add,
                                            color: _corLaranjaSF,
                                            size: 30,
                                          ),
                                        ),
                                        Text("Adicionar Itens", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                      ],
                                    ),),
                                )
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                                height: 50,
                                width: 170,
                                child: Expanded(
                                  child: ElevatedButton(
                                    onPressed: (){
                                      if(pedido_selecionado.total <= 0)
                                      {
                                        final snackBar = SnackBar(
                                          content: const Text('O pedido não possui itens', style: TextStyle(color: Colors.white),),
                                          backgroundColor: _corLaranjaSF,
                                          duration: Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Ok',
                                            textColor: _corMarromSF,
                                            onPressed: () {
                                              // Some code to undo the change.
                                            },
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                      else{
                                        _recuperar_itens_reimprimir_pedido(pedido_selecionado.identificador, pedido_selecionado.id_pedido);
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      primary: _corMarromSF,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                          child: Icon(
                                            Icons.print,
                                            color: _corLaranjaSF,
                                            size: 30,
                                          ),
                                        ),
                                        Text("Reimprimir", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                      ],
                                    ),
                                  ),
                                )
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                                height: 50,
                                width: 170,
                                child: Expanded(
                                  child: ElevatedButton(
                                    onPressed: (){
                                      if(pedido_selecionado.total <= 0)
                                      {
                                        final snackBar = SnackBar(
                                          content: const Text('O pedido não possui itens', style: TextStyle(color: Colors.white),),
                                          backgroundColor: _corLaranjaSF,
                                          duration: Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Ok',
                                            textColor: _corMarromSF,
                                            onPressed: () {
                                              // Some code to undo the change.
                                            },
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                      else{
                                        Navigator.of(context).pop();
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => Visualizar(0, pedido_selecionado.identificador, _parametros.qtd_vias_imprimir, _parametros.ip_impressora)
                                            )
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      primary: _corMarromSF,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                          child: Icon(
                                            Icons.edit,
                                            color: _corLaranjaSF,
                                            size: 30,
                                          ),
                                        ),
                                        Text("Itens do Pedido", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                      ],
                                    ),
                                  ),
                                )
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                                height: 50,
                                width: 170,
                                child: Expanded(
                                  child: ElevatedButton(
                                    onPressed: (){
                                      if(pedido_selecionado.total <= 0)
                                      {
                                        final snackBar = SnackBar(
                                          content: const Text('O pedido não possui itens', style: TextStyle(color: Colors.white),),
                                          backgroundColor: _corLaranjaSF,
                                          duration: Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Ok',
                                            textColor: _corMarromSF,
                                            onPressed: () {
                                              // Some code to undo the change.
                                            },
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                      else{
                                        _gerar_dialogo_deletar_pedido(pedido_selecionado);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      primary: _corMarromSF,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                          child: Icon(
                                            Icons.delete_outline,
                                            color: _corLaranjaSF,
                                            size: 30,
                                          ),
                                        ),
                                        Text("Excluir Pedido", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                      ],
                                    ),
                                  ),
                                )
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(4),
                            child: Container(
                                height: 50,
                                width: 170,
                                child: Expanded(
                                  child: ElevatedButton(
                                    onPressed: (){
                                      if(pedido_selecionado.total <= 0)
                                      {
                                        final snackBar = SnackBar(
                                          content: const Text('O pedido não possui itens', style: TextStyle(color: Colors.white),),
                                          backgroundColor: _corLaranjaSF,
                                          duration: Duration(seconds: 2),
                                          action: SnackBarAction(
                                            label: 'Ok',
                                            textColor: _corMarromSF,
                                            onPressed: () {
                                              // Some code to undo the change.
                                            },
                                          ),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      }
                                      else{
                                        _gerar_dialogo_fechar_pedido(pedido_selecionado);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                      primary: _corMarromSF,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
                                          child: Icon(
                                            Icons.monetization_on_outlined,
                                            color: _corLaranjaSF,
                                            size: 30,
                                          ),
                                        ),
                                        Text("Fechar Pedido", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.left)
                                      ],
                                    ),
                                  ),
                                )
                            ),
                          ),
                          TextButton(onPressed: () {
                            Navigator.of(context).pop();
                          },
                              child: Text('Sair', style: TextStyle(color: _corMarromSF, fontSize: 16.0),))
                        ],
                      ),
                    ),
                  ),
                ),
                onWillPop: () async => true
            )
        ),
      ),
    );
  }

  mostrarDialogoParametros()
  {
    int _primeiro_acesso = 0; // 0 - NAO || 1 - SIM
    if(_parametros.qtd_mesas == 0)
      _primeiro_acesso = 1;
    _parametro_qtd_mesas_antigo = _parametros.qtd_mesas;
    _controllerNome.text = _parametros.nome_garcom.toString();
    _controllerQtdMesas.text = _parametros.qtd_mesas.toString();
    _controllerQtdColunas.text = _parametros.qtd_colunas.toString();
    _controllerQtdVias.text = _parametros.qtd_vias_imprimir.toString();
    _controllerIpImp.text = _parametros.ip_impressora.toString();
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
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: Text('Parâmetros', style: TextStyle(color: Color(0xff3d2314), fontSize: 28, fontWeight: FontWeight.w900),),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerNome,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              maxLength: 25,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                  color: Color(0xffff6900),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "Nome do Garçom",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerQtdMesas,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 2,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                  color: Color(0xffff6900),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "Quantidade de Mesas",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerQtdColunas,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 2,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                  color: Color(0xffff6900),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "Quantidade de Colunas",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerQtdVias,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              maxLength: 2,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                  color: Color(0xffff6900),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "Quantidade de Vias Imprimir",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding:  EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _controllerIpImp,
                              keyboardType: TextInputType.number,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              maxLength: 15,
                              cursorColor: Color(0xff3d2314),
                              style: TextStyle(
                                color: Color(0xffff6900),
                                fontSize: 16,
                                fontWeight: FontWeight.w700
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                labelText: "IP da Impressora",
                                labelStyle: TextStyle(color: Color(0xff3d2314)),
                                fillColor: Colors.white,
                                hoverColor: Color(0xff3d2314),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(width: 2, color: Color(0xff3d2314)),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                              padding: EdgeInsets.all(8)),
                          TextButton(onPressed: () {
                            FocusScope.of(context).unfocus();
                            if(!_controllerNome.text.isEmpty && !_controllerQtdMesas.text.isEmpty && !_controllerQtdVias.text.isEmpty && int.parse(_controllerQtdMesas.text) > 0 && !_controllerQtdVias.text.isEmpty && int.parse(_controllerQtdMesas.text) > 0 && !_controllerQtdColunas.text.isEmpty && int.parse(_controllerQtdColunas.text) > 0 && !_controllerIpImp.text.isEmpty)
                            {
                              int _qtd_adicionar = 0;
                              int _qtd_remover = 0;
                              if(_parametro_qtd_mesas_antigo != int.parse(_controllerQtdMesas.text))
                              {
                                if(_parametro_qtd_mesas_antigo > int.parse(_controllerQtdMesas.text) && _listaMesas.length > 0) //remoção de mesas
                                    {//é necessário verificar se as últimas mesas da lista não estão em aberto, para somente depois disso remover
                                  _qtd_remover = _parametro_qtd_mesas_antigo - int.parse(_controllerQtdMesas.text);
                                  bool _pode_excluir = true;
                                  for(int i = _listaMesas.length; i >= int.parse(_controllerQtdMesas.text); i--)
                                  {
                                    if(_listaMesas[i-1].status == 1)//mesa aberta, não pode ser excluída
                                        {
                                      _pode_excluir = false;
                                      break;
                                    }

                                  }
                                  if(!_pode_excluir)
                                  {
                                    final snackBar = SnackBar(
                                      backgroundColor: Color(0xff3d2314),
                                      content: Text(
                                        'Não é possível excluir mesas que estão em aberto. Feche-as para executar este processo',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.white
                                        ),
                                      ),
                                      action: SnackBarAction(
                                        label: 'Ok',
                                        textColor: Colors.blueAccent,
                                        onPressed: () {
                                        },
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                    return;
                                  }
                                }
                                if(_parametro_qtd_mesas_antigo < int.parse(_controllerQtdMesas.text) && _listaMesas.length > 0) //adição de mesas
                                    {//adicionar mais mesas
                                  _qtd_adicionar = int.parse(_controllerQtdMesas.text) - _parametro_qtd_mesas_antigo;
                                }
                              }

                              _parametros.nome_garcom = _controllerNome.text;
                              _parametros.qtd_mesas = int.parse(_controllerQtdMesas.text);
                              _parametros.qtd_colunas = int.parse(_controllerQtdColunas.text);
                              _parametros.qtd_vias_imprimir = int.parse(_controllerQtdVias.text);
                              _parametros.ip_impressora = _controllerIpImp.text;

                              if(_qtd_adicionar == 0 && _qtd_remover == 0)//sem alteração
                                _salvarParametros(_primeiro_acesso);
                              if(_qtd_adicionar != 0 && _qtd_remover == 0)//aumento de mesas
                                  {
                                _salvarParametros(_primeiro_acesso);
                                _alterarMesas(0, _qtd_adicionar);
                              }
                              if(_qtd_adicionar == 0 && _qtd_remover != 0)//redução de mesas
                                  {
                                _salvarParametros(_primeiro_acesso);
                                _alterarMesas(1, _qtd_remover);
                              }

                              Navigator.of(context).pop();
                            }
                            else
                            {
                              final snackBar = SnackBar(
                                backgroundColor: Color(0xff3d2314),
                                content: Text(
                                  'Existem campos não preenchidos ou preenchidos incorretamente. Verifique e tente novamente.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white
                                  ),
                                ),
                                action: SnackBarAction(
                                  label: 'Ok',
                                  textColor: Colors.blueAccent,
                                  onPressed: () {
                                  },
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                            }
                          },
                              child: Text('Salvar', style: TextStyle(color: _corLaranjaSF, fontSize: 18.0, fontWeight: FontWeight.w800),))
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
  _recupera_infos_mesas_existentes(String _nome, int _qtd) async
  {
    _listaMesas.clear();
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("mesas").get();
    if (snapshot.exists) {
      for(DataSnapshot ds in snapshot.children)
      {
        Mesa _itemLista = Mesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = Mesa.fromJson(json);
        _listaMesas.add(_itemLista);
      }
      _recuperarPedidos(_nome, _qtd);
    }
  }
  _alterarMesas(int parametro, int qtd) async{//0 - adicionar | 1 - remover
    if(parametro == 0){//adicionar mesas
      int _ultima_mesa_registrada = _listaMesas.last.numero;
      for(int i = 1; i <= qtd; i++)
      {
        Mesa _mesa = Mesa();
        _mesa.numero = i + _ultima_mesa_registrada;
        _mesa.status = 0;
        _mesa.total = 0;
        final json = _mesa.toJson();
        final ref = FirebaseDatabase.instance.ref("mesas/" + _mesa.numero.toString());
        await ref.set(json);
      }
      _carregaDadosMesas(_parametros.nome_garcom, _parametros.qtd_colunas);
    }
    else{//remover mesas
      int novo_total = _listaMesas.length - qtd;
      for(int i = _listaMesas.length; i > novo_total; i--)
      {
        await FirebaseDatabase.instance.ref().child('mesas/').child(i.toString()).remove();
      }
    }
    _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
  }

  _recuperar_itens_reimprimir(int _numero_mesa) async{
    _listaItensMesa.clear();
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("imprimir/" + _numero_mesa.toString()).get();
    if (snapshot.exists) {
      final json = snapshot.value as List;
      for(DataSnapshot ds in snapshot.children)
      {
        ItemMesa _itemLista = ItemMesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = ItemMesa.fromJson(json);
        _listaItensMesa.add(_itemLista);
      }
    }
    _reimprimir_mesa(_numero_mesa);
  }

  _reimprimir_mesa(int num_mesa) async
  {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(_parametros.ip_impressora.toString(), port: 9100); //10.253.0.98 _parametros.ip_impressora.toString()

    if (res == PosPrintResult.success) {
      //verificar a qtd de vias para imprimir
      for(int i = 0; i < _parametros.qtd_vias_imprimir; i++)
      {
        _gerar_impressao(printer, num_mesa);
      }
      printer.disconnect();
    }

    print('Print result: ${res.msg}');
  }

  Future<void> _gerar_impressao(NetworkPrinter printer, int numero_mesa) async {

    DateTime now = DateTime.now();
    String data = DateFormat('kk:mm:ss').format(now);

    //Cabeçalho da impressão
    printer.text("Mesa " + numero_mesa.toString(),
        styles: PosStyles(
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.center
        ));
    printer.text("Hora: " + data,
        styles: PosStyles(
            align: PosAlign.center
        ));
    printer.text("Garcom: " + _remove_diacritics(_parametros.nome_garcom.toString()),
        styles: PosStyles(
            align: PosAlign.center
        ));
    String _obs_cozinha = _listaItensMesa[0].desc_item.toString();
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
    for(int i = 1; i < _listaItensMesa.length; i++)
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

  _recuperar_itens_reimprimir_pedido(String _identificador, int _id) async{
    _listaItensMesa.clear();
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("itens-pedido/" + _identificador.toString()).get();
    if (snapshot.exists) {
      final json = snapshot.value as List;
      for(DataSnapshot ds in snapshot.children)
      {
        ItemMesa _itemLista = ItemMesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = ItemMesa.fromJson(json);
        _listaItensMesa.add(_itemLista);
      }
    }
    Pedido pedido_recuperado_reimprimir = Pedido();
    pedido_recuperado_reimprimir = _listaPedidos.firstWhere((it) => it.identificador == _identificador);
    _reimprimir_pedido(pedido_recuperado_reimprimir);
  }

  _reimprimir_pedido(Pedido reimprimir) async
  {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(_parametros.ip_impressora.toString(), port: 9100); //10.253.0.98 _parametros.ip_impressora.toString()

    if (res == PosPrintResult.success) {
      //verificar a qtd de vias para imprimir
      for(int i = 0; i < _parametros.qtd_vias_imprimir; i++)
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
    _valor_mostrar = NumberFormat.simpleCurrency(locale: 'pt_BR').format(_calcula_total_itens_lista());
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

  num _calcula_total_itens_lista()
  {
    num _total_inserir_mesa = 0;
    for(ItemMesa it in _listaItensMesa)
    {
      _total_inserir_mesa = _total_inserir_mesa + it.valor_tot;
    }
    return _total_inserir_mesa;
  }

  num _calcula_valor_taxa_reimprimir(num total)
  {
    num _total_itens = _calcula_total_itens_lista();
    num _taxa = total - _total_itens;
    return _taxa;
  }

  _gerar_dialogo_deletar_pedido(Pedido pedido_excluir)
  {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text('Remover Pedido'),
            content: const Text('Deseja realmente excluir este pedido?'),
            actions: [
              TextButton(
                  onPressed: () {
                    _remover_pedido(pedido_excluir);
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    setState(() {
                      _visibility = false;
                      _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
                    });
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

  _remover_pedido(Pedido pedido_excluir) async{
    await FirebaseDatabase.instance.ref().child('pedidos').child(pedido_excluir.id_pedido.toString()).remove();
    await FirebaseDatabase.instance.ref().child('itens-pedido').child(pedido_excluir.identificador.toString()).remove();
  }

  _gerar_dialogo_fechar_pedido(Pedido pedido_selecionado)
  {
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text('Fechar Pedido'),
            content: const Text('Esta ação salvará os dados deste pedido para consultas em relatórios do sistema. Deseja realmente fechar este pedido?'),
            actions: [
              TextButton(
                  onPressed: () {
                    _fechar_pedido(pedido_selecionado);
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

  _fechar_pedido(Pedido _fechar) async
  {
    mostrarDialogoSalvando();
    _listaItensMesa.clear();
    final ref = FirebaseDatabase.instance.ref();
    final snapshot = await ref.child("itens-pedido/" + _fechar.identificador.toString()).get();
    if (snapshot.exists) {
      final json = snapshot.value as List;
      for(DataSnapshot ds in snapshot.children)
      {
        ItemMesa _itemLista = ItemMesa();
        final json = ds.value as Map<dynamic, dynamic>;
        _itemLista = ItemMesa.fromJson(json);
        _listaItensMesa.add(_itemLista);
      }
    }
    //registro de comanda
    Comanda _pagamento_salvar = Comanda();
    _pagamento_salvar.id = _fechar.identificador;
    _pagamento_salvar.total = _fechar.total;
    _pagamento_salvar.mesa = 0;
    _pagamento_salvar.data = _fechar.data;
    _pagamento_salvar.pagamento = _fechar.pagamento;
    _pagamento_salvar.fechamento = 1;
    //registro itens comanda
    for(int i = 1; i <= _listaItensMesa.length; i++)
    {
      ItemComanda _item_salvar = ItemComanda();
      _item_salvar.id = _fechar.identificador;//id_registro;
      _item_salvar.mesa = 0;
      _item_salvar.data = _fechar.data;
      _item_salvar.nome = _listaItensMesa[i-1].desc_item;
      _item_salvar.valor = _listaItensMesa[i-1].valor_tot;
      _item_salvar.qtd = _listaItensMesa [i-1].qtd;
      _listaItensMesaTotalRelatorio.add(_item_salvar);
    }
    for(int i = 1; i <= _listaItensMesaTotalRelatorio.length; i++)
    {
      final json0 = _listaItensMesaTotalRelatorio[i-1].toJson();
      String chave_firebase = i.toString() + "_" + _listaItensMesaTotalRelatorio[i-1].id;
      final ref_comanda_item = FirebaseDatabase.instance.ref("fechado-itens/" + chave_firebase);
      await ref_comanda_item.set(json0);
    }
    final json1 = _pagamento_salvar.toJson();
    final ref_comanda = FirebaseDatabase.instance.ref('fechado/' + _fechar.identificador);
    await ref_comanda.set(json1);

    if(_fechar.tipo == 1){
      //nova entrega
      Entrega _nova_ent = Entrega();
      _nova_ent.total = _fechar.total;
      _nova_ent.taxa = _calcula_valor_taxa_reimprimir(_fechar.total);
      _nova_ent.pagamento = _fechar.pagamento;

      final json2 = _nova_ent.toJson();
      final ref_entrega = FirebaseDatabase.instance.ref('entrega/' + _fechar.identificador);
      await ref_entrega.set(json2);
    }

    await FirebaseDatabase.instance.ref().child('pedidos').child(_fechar.id_pedido.toString()).remove();
    await FirebaseDatabase.instance.ref().child('itens-pedido').child(_fechar.identificador.toString()).remove();

    Navigator.of(context).pop();
    Navigator.of(context).pop();
    Navigator.of(context).pop();
    setState(() {
      _visibility = false;
      _recupera_infos_mesas_existentes(_parametros.nome_garcom, _parametros.qtd_colunas);
    });
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
                                'Fechando o pedido...',
                                style: TextStyle(color: _corMarromSF),
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
}


