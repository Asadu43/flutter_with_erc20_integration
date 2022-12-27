import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:web3/web3.dart';
import 'package:web3dart/contracts.dart';
import 'package:web3dart/credentials.dart';
import 'package:web3dart/web3dart.dart';



class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var  _uri,account;
  SessionStatus?  _session;
  var myData = BigInt.zero;
  late Client client;
  late Web3Client web3client;
  late DeployedContract contract;
  String? name;
  String? symbol;
  String contractAddress = "0xB4F284Df7D40f40327db4A27C855BB1f909891c2";
  final rpc_url ="https://goerli.infura.io/v3/4009a1b4ddf34fc6ad587c4b10dabe52";


  var connector = WalletConnect(
      bridge: 'https://bridge.walletconnect.org',
      clientMeta: const PeerMeta(
          name: 'My App',
          description: 'An app for Connect with MetaMask and Send Transaction',
          url: 'https://walletconnect.org',
          icons: [
            'https://files.gitbook.com/v0/b/gitbook-legacy-files/o/spaces%2F-LJJeCjcLrr53DcT1Ml7%2Favatar.png?alt=media'
          ]));

  loginUsingMetamask(BuildContext context) async {
    if (!connector.connected) {
      try {
        var session = await connector.createSession(onDisplayUri: (uri) async {
          _uri = uri;
          await launchUrlString(uri, mode: LaunchMode.externalApplication);
          contract = await loadContract();
        });
        setState(() {
          _session = session;
          account = _session!.accounts[0];
        });
      } catch (exp) {
        print(exp);
      }
    }
  }

  Future<DeployedContract> loadContract() async {
    String abi = await rootBundle.loadString("assets/abi.json");
    final contract = DeployedContract(ContractAbi.fromJson(abi, "AsadToken"),EthereumAddress.fromHex(contractAddress));
    return contract;
  }
  Future<List<dynamic>> query(String name, List<dynamic> args) async {
    final contract = await loadContract();
    final ethFunction = contract.function(name);
    final result = await web3client.call(
        contract: contract, function: ethFunction, params: args);
    return result;
  }

  Future getTokenName() async{
    var response = await query("name", []);
    name = response[0];
    setState(() {});
  }
  Future getTokenSymbol() async{
    var response = await query("symbol", []);
    symbol = response[0];
    setState(() {});
  }

  Future getBalanceToken(String targetAddress) async{
    EthereumAddress toAddress =  EthereumAddress.fromHex(targetAddress);
    var response = await query("balanceOf", [toAddress]);
    myData = response[0];
    setState(() {});
  }
  Future mintToken(BuildContext context) async {
    BigInt bigAmount = BigInt.from(5 * pow(10,18));
    EthereumAddress toAddress =  EthereumAddress.fromHex(_session!.accounts[0]);
    var response = await submit("mint", [toAddress,bigAmount]);
    return response;
  }

  Future transferToken(BuildContext context) async {
    BigInt bigAmount = BigInt.from(1 * pow(10,18));
    EthereumAddress toAddress =  EthereumAddress.fromHex("0x95d214e60C1881FAcfca90D8909F0DdEE63F004f");
    var response = await submit("transfer", [toAddress,bigAmount]);
    return response;
  }

  submit(String name, List<dynamic> args) async {


    if (connector.connected) {
      try {
        EthereumWalletConnectProvider provider =
        EthereumWalletConnectProvider(connector);
        await launchUrlString(_uri, mode: LaunchMode.externalApplication);
        var data = contract.function(name).encodeCall(args);
        await provider.sendTransaction(
          from: _session!.accounts[0],
          to: contractAddress,
          gas: 320000,
          data: data,
        );
      } catch (exp) {
        print(exp);
      }
    }else{
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please Connect with Metamask"),
      ));
    }
  }

  @override
  void initState()  {
    super.initState();
    client = Client();
    web3client = Web3Client(rpc_url, client);
    // contract = await loadContract();
    // getBalanceToken(_session?.accounts[0] ?? "");
  }

  @override
  Widget build(BuildContext context) {
    if(_session != null) {
      getBalanceToken(_session?.accounts[0] ?? "");
      getTokenName();
      getTokenSymbol();
    }
    return  Scaffold(
      appBar: AppBar(
        title: const Text("ERC20 Integration"),
        centerTitle: true,
      ),
      drawer: Drawer(
          child: ListView(
            children: [
              (_session != null)
                  ? UserAccountsDrawerHeader(
                accountName: const Text("Asad"),
                accountEmail: Text(account),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text("A"),
                ),
              )
                  : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent),
                  onPressed: () => loginUsingMetamask(context),
                  child: const Text("Connect with Metamask")),
            ],
          )),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50),
            margin: const EdgeInsets.all(10),
            child: Text(
              name ?? "",
              style: const TextStyle(fontSize: 40),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 50),
            margin: const EdgeInsets.all(10),
            child: Text(
              "${EtherAmount.inWei(myData).getInEther} ${symbol ?? "Coin"}",
              style: const TextStyle(fontSize: 40),
            ),
          ),
          Center(
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent),
                onPressed: () => mintToken(context),
                child: const Text("Mint Token")),
          ),
          Center(
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red),
                onPressed: () => transferToken(context),
                child: const Text("Transfer Token")),
          ),
        ],
      ),

    );
  }
}
