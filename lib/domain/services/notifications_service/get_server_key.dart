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
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC+lIC6HhT/WKY2\nwRDbYfhOghTMOPxUYYPdZ2VE8Ef3Oo6roA43Ugja59Zgl/upW40eKcZF8HR3NWw8\nllv+RLN+xv2RG95ElHgvAt4+WJ9/hh5q44Q2svN4q1HD2GSwOb87Ic1UUeSOlTHT\nSbYIKv5OCRIL5rbCKFeaicbRSsTIpmsSPP7lo6JPVn8mUp9Urs6SfXUJT3BY+FhX\nBSekx1ocoxFFGsxInj//Vq65MlHSc2cQV89rp1OuEJ0nHNnT7gGH7kVPLWr+eAhr\n4sNHjj0wQYN83MchbB13D7mSbce+BiSFUOGCv5pOr3zGs99QtWsRCXfcFdKgLrYY\n/GjyrXPnAgMBAAECggEAQh2iyu7EuhE3GKfCAVnrmtDmBjN+1oc+CAFm0JPLY6mc\n9U2BoQ+EouzrIneXhxmLy3sSnhDdVr3h3uMK5xtOahz+uujAI2qehzCniVmVe9g7\nlTl5FMDgVmyY4SihRcHC5fDEGwyODikUMAjSbeL8dnYPHLHdlV4JhkNmBhW6TyFS\nspNgA8UqtRr4lNzAfEBjXCmPIotSRYr/G/p1s283nKF7+bjteXrn+fUsjlENah9Z\nKy+FFqeXNjIUwGyXSjetbC/nNemZVE/rk3uIB5VUle0zQVtDiZROFKmXSNCRgj3T\nui/Myd0sngPGe5q0kE/tGlNiDAdCw7IBeTpilKGXAQKBgQD2qe3sXTUmO6A8Irxd\n25rae6+1wDQnXtbmGXvtgm6zvNj5kNZ1J30EL3TpFhtQoEfvwLxqox2Lcm3ktX/x\nQEJ/KLBFi9uKx6h+PVkrMgstrN/hBbb60wle9h06ZhR+j7bERu+u7W/YrasWipJc\nXlKwH7GD/rini9pPlgzRIiuTqQKBgQDFyyU/T5/dPrR8fDsJhgoMoQRjFxYBoEOf\nj5Qyl2Q8T0r8jgTYRfeZ+m44LR2JzsLCUSFtAD5SQagAej7H5GQU+XwdPi0h/n+N\nYuHrpAtM/9knb5kKw/BCdMpeLYV82oupHbtgafZTm8nMY8Bn+s1pN5k1oLokSlKK\nantCnMGFDwKBgDIZW5C5cbUdQTNVnsq1cuNTYeHZcv5YHe/IV0prRo7NGYi+6UAM\nUDEMboN1EQE0PMgublZ+YN7U1Asy7hSTB66KFhtaB7JNUSSq0zSZynlxdlte7MZP\nHMUj2dXlq9301JtTCRWPdjsdMvW2GXoXUlYhac20a87j8eheQqYreYxZAoGBAJLw\ngwBQt/PWNKFSbU167ZZKPIcczHVyySoNsUwQWh/PzGZpX0IIYJRcjmtfYNVS7C8N\ntKZUivfy3MtWBbPcgVlvqnvTCBZ8CehQcIPtf5O5cmqwpmJwA9prBzgF22hQt3Zw\npxZOQfgFAVq9NGBK2zTyX/iOKhrxt/Yqet2WtNGTAoGBAKgMCSmTjkomGKlEeBMZ\nrugN98T8t8gKkJSCB71+SXgMk8NmP+Yc/gaV0TIBnyicr/MjkBdKmDsTBIfhC3zB\nYhRmA7dUy2bkFGY0Sut9Mi1LVgI1OVk/64a81wUaFZexBxISmRb4lQ3RmH/Ptkb7\n8aaaSkmkOwm4+J9gxC2+Rdgs\n-----END PRIVATE KEY-----\n",
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