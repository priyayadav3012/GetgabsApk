import 'package:googleapis_auth/auth_io.dart';

class GetServerKey{
Future<String>getServerToken()async{
  final scopes = [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/firebase.database",
    "https://www.googleapis.com/auth/firebase.messaging"
  ];  

  final client  =await clientViaServiceAccount(ServiceAccountCredentials.fromJson(
{
  "type": "service_account",
  "project_id": "getgabs-notif",
  "private_key_id": "c9342555dbe6920c012a5443410a2d77fa1343ef",
  "private_key": "",
  "client_email": "getgabs-notification@getgabs-notif.iam.gserviceaccount.com",
  "client_id": "113106107147647485033",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/getgabs-notification%40getgabs-notif.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
  ), scopes);
  final accessServerKey=client.credentials.accessToken.data;
  return accessServerKey ;
}
}