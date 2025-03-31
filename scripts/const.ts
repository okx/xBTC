import { Aptos, AptosConfig, Ed25519PrivateKey, Network, Account } from "@aptos-labs/ts-sdk";


export const XBTC_CONTRACT_ADDRESS = "0x8e17e166bcd06535d7fbd016c3ca2ebf23cb515423f75fcf30e2516d9070918c";


export const RECIPIENT_ADDRESS = "0x13526c24d1785380dacb52ae6c242475e08ad7b5a8ecf324b2895e6790456732";
export const ACCOUNT2 = "0x309a61cdc6eccd1cbc816b1805c7d1e96311840109428e4c3b134cb7490357d6"
export const ONE_BTC_AMOUNT = 100000000; // 1 XBTC

export function getAptosClient(network: Network) {
    const config = new AptosConfig({ network: network });
    return new Aptos(config);
  }
  
export function getAccount() {
const privateKey = getSignedPrivkey();
    const account = Account.fromPrivateKey({ privateKey: privateKey });
    console.log(`account address: ${account.accountAddress}`);
    return account;
}

export function getAccount2() {
    const privateKey = getSignedPrivkey2();
    const account = Account.fromPrivateKey({ privateKey: privateKey });
    console.log(`account2 address: ${account.accountAddress}`);
    return account;
}

export function getPrivkey() {
    const  my_privateKey = process.env.TEST_PRIVATE_KEY || '';
    return my_privateKey
}

export function getSignedPrivkey() {
    const  my_privateKey = getPrivkey();
    const privateKey = new Ed25519PrivateKey(my_privateKey);
    return privateKey
}

export function getSignedPublicKey() {
    const  my_privateKey = getPrivkey();
    const privateKey = new Ed25519PrivateKey(my_privateKey);
    const publicKey = toHexString((privateKey.publicKey()).toUint8Array());
    return publicKey
}


export function getPrivkey2() {
    const  my_privateKey = process.env.TEST_PRIVATE_KEY || '';
    return my_privateKey
}

export function getSignedPrivkey2() {
    const  my_privateKey = getPrivkey2();
    const privateKey = new Ed25519PrivateKey(my_privateKey);
    return privateKey
}

export function fromHexString (hexString:string){
    if (hexString.startsWith('0x')) {
        hexString = hexString.slice(2)
    }
    // const hex = Uint8Array.from(Buffer.from(hexString, 'hex'));
    var bytes = new Uint8Array(Math.ceil(hexString.length / 2));
    for (var i = 0; i < bytes.length; i++) bytes[i] = parseInt(hexString.substr(i * 2, 2), 16);
    // console.log(bytes)
    return bytes
    // return Array.from(bytes)
}

export function toHexString(byteArray: Uint8Array) {
    var s = '0x';
    byteArray.forEach(function(byte) {
      s += ('0' + (byte & 0xFF).toString(16)).slice(-2);
    });
    return s;
}
export function signMsg (privateKey: Ed25519PrivateKey,msg: any){
    let sig = privateKey.sign(msg);
    console.log('msg',msg.toString())
    console.log('signedMessage',sig.toString())
    return sig.toUint8Array()
}