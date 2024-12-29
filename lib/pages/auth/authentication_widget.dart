import '/auth/firebase_auth/auth_util.dart';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'authentication_model.dart';
import '/utils/responsive_utils.dart';
import 'package:go_router/go_router.dart';


class AuthenticationWidget extends StatefulWidget {
  const AuthenticationWidget({super.key});

  @override
  State<AuthenticationWidget> createState() => _AuthenticationWidgetState();
}

class _AuthenticationWidgetState extends State<AuthenticationWidget> {
  late final bool isAndroid;

  // 상태 필드
  late AuthenticationModel _model;
  late TextEditingController emailAddressTextController;
  late FocusNode emailAddressFocusNode;
  
  late TextEditingController passwordTextController;
  late FocusNode passwordFocusNode;
  bool passwordVisibility = false;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    isAndroid = Theme.of(context).platform == TargetPlatform.android;
    _model = AuthenticationModel();
    emailAddressTextController = TextEditingController();
    emailAddressFocusNode = FocusNode();

    passwordTextController = TextEditingController();
    passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    emailAddressFocusNode.dispose();
    emailAddressTextController.dispose();

    passwordFocusNode.dispose();
    passwordTextController.dispose();

    super.dispose();
  }

  void safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          top: true,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  width: 100.0,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  alignment: AlignmentDirectional(0.0, -1.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (responsiveVisibility(
                          context: context,
                          phone: false,
                          tablet: false,
                        ))
                          Container(
                            width: double.infinity,
                            height: 140.0,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(16.0),
                                bottomRight: Radius.circular(16.0),
                                topLeft: Radius.circular(0.0),
                                topRight: Radius.circular(0.0),
                              ),
                            ),
                          ),
                        if (responsiveVisibility(
                          context: context,
                          tabletLandscape: false,
                          desktop: false,
                        ))
                          Container(
                            width: double.infinity,
                            height: 140.0,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(16.0),
                                bottomRight: Radius.circular(16.0),
                                topLeft: Radius.circular(0.0),
                                topRight: Radius.circular(0.0),
                              ),
                            ),
                            alignment: AlignmentDirectional(-1.0, 0.0),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  24.0, 0.0, 0.0, 0.0),
                              child: Text(
                                'brand.ai',
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            maxWidth: 430.0,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional(0.0, 0.0),
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome Back',
                                    style: Theme.of(context).textTheme.headlineLarge,
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 12.0, 0.0, 24.0),
                                    child: Text(
                                      'Let\'s get started by filling out the form below.',
                                      style: Theme.of(context).textTheme.labelMedium,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 16.0),
                                    child: Container(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller:
                                            emailAddressTextController,
                                        focusNode: emailAddressFocusNode,
                                        autofocus: true,
                                        autofillHints: [AutofillHints.email],
                                        obscureText: false,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          labelStyle: Theme.of(context).textTheme.labelLarge,
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Theme.of(context).colorScheme.background,
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Theme.of(context).colorScheme.primary,
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Theme.of(context).colorScheme.error,
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Theme.of(context).colorScheme.error,
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          filled: true,
                                          fillColor: Theme.of(context).colorScheme.background,
                                        ),
                                        style: Theme.of(context).textTheme.bodyLarge,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: _model.emailAddressTextControllerValidator,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 16.0),
                                    child: Container(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller:
                                            passwordTextController,
                                        focusNode: passwordFocusNode,
                                        autofocus: true,
                                        autofillHints: [AutofillHints.password],
                                        obscureText: !passwordVisibility,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          labelStyle: Theme.of(context).textTheme.labelLarge,
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Theme.of(context).colorScheme.background,
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Theme.of(context).colorScheme.primary,
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Theme.of(context).colorScheme.error,
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Theme.of(context).colorScheme.error,
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          filled: true,
                                          fillColor: Theme.of(context).colorScheme.background,
                                          suffixIcon: InkWell(
                                            onTap: () => safeSetState(
                                              () => passwordVisibility =
                                                  !passwordVisibility,
                                            ),
                                            focusNode: FocusNode(skipTraversal: true),
                                            child: Icon(
                                              passwordVisibility
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              color: Theme.of(context).textTheme.bodySmall?.color,
                                              size: 24.0,
                                            ),
                                          ),
                                        ),
                                        style: Theme.of(context).textTheme.bodyLarge,
                                        validator: _model.passwordTextControllerValidator,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 16.0),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final user =
                                            await authManager.signInWithEmail(
                                          context,
                                          emailAddressTextController.text,
                                          passwordTextController.text,
                                        );
                                        if (user == null) {
                                          return;
                                        }

                                        context.pushNamed('CreateGoals');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        textStyle: Theme.of(context).textTheme.titleSmall,
                                        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                                        elevation: 3.0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.0),
                                        ),
                                      ),
                                      child: Text('Sign In'),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 24.0),
                                    child: Container(
                                      width: 370.0,
                                      child: Stack(
                                        alignment: AlignmentDirectional(0.0, 0.0),
                                        children: [
                                          Align(
                                            alignment: AlignmentDirectional(0.0, 0.0),
                                            child: Padding(
                                              padding: EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 12.0, 0.0, 12.0),
                                              child: Container(
                                                width: double.infinity,
                                                height: 2.0,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.background,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: AlignmentDirectional(0.0, 0.0),
                                            child: Container(
                                              width: 70.0,
                                              height: 32.0,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surface,
                                              ),
                                              alignment: AlignmentDirectional(0.0, 0.0),
                                              child: Text(
                                                'OR',
                                                style: Theme.of(context).textTheme.labelMedium,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 16.0),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final user = await authManager
                                            .signInWithGoogle(context);
                                        if (user == null) {
                                          return;
                                        }

                                        context.pushNamed('CreateGoals');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.surface,
                                        textStyle: Theme.of(context).textTheme.titleSmall,
                                        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                                        elevation: 0.0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.0),
                                          side: BorderSide(
                                            color: Theme.of(context).colorScheme.error,
                                            width: 2.0,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          FaIcon(
                                            FontAwesomeIcons.google,
                                            size: 20.0,
                                          ),
                                          SizedBox(width: 8.0),
                                          Text('Continue with Google'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Theme.of(context).platform == TargetPlatform.android
                                      ? Container()
                                      : Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 0.0, 16.0),
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final user = await authManager
                                                  .signInWithApple(context);
                                              if (user == null) {
                                                return;
                                              }

                                              context.pushNamed('CreateGoals');
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(context).colorScheme.surface,
                                              textStyle: Theme.of(context).textTheme.titleSmall,
                                              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                                              elevation: 0.0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                side: BorderSide(
                                                  color: Theme.of(context).colorScheme.error,
                                                  width: 2.0,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                FaIcon(
                                                  FontAwesomeIcons.apple,
                                                  size: 20.0,
                                                ),
                                                SizedBox(width: 8.0),
                                                Text('Continue with Apple'),
                                              ],
                                            ),
                                          ),
                                        ),

                                  // You will have to add an action on this rich text to go to your login page.
                                  Align(
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 12.0, 0.0, 12.0),
                                      child: RichText(
                                        textScaler: MediaQuery.of(context).textScaler,
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Don\'t have an account? ',
                                              style: TextStyle(),
                                            ),
                                            TextSpan(
                                              text: 'Sign Up here',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                              mouseCursor: SystemMouseCursors.click,
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () async {
                                                  context.pushNamed(
                                                      'CreateAccount');
                                                },
                                            )
                                          ],
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (responsiveVisibility(
                context: context,
                phone: false,
                tablet: false,
              ))
                Expanded(
                  flex: 8,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Container(
                      width: 100.0,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary
                          ],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(1.0, -1.0),
                          end: AlignmentDirectional(-1.0, 1.0),
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                maxWidth: 400.0,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 3.0,
                                    color: Color(0x2E000000),
                                    offset: Offset(
                                      0.0,
                                      2.0,
                                    ),
                                  )
                                ],
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.background,
                                  width: 2.0,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          12.0, 12.0, 12.0, 8.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 8.0, 0.0),
                                                child: Container(
                                                  width: 40.0,
                                                  height: 40.0,
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFFEEEEEE),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.person,
                                                    color: Theme.of(context).colorScheme.primary,
                                                    size: 24.0,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                'UserName',
                                                style: Theme.of(context).textTheme.titleMedium,
                                              ),
                                            ],
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.max,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Overall',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Padding(
                                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 4.0, 0.0),
                                                    child: Text(
                                                      '5',
                                                      style: Theme.of(context).textTheme.headlineMedium,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.star_rounded,
                                                    color: Theme.of(context).colorScheme.primary,
                                                    size: 20.0,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          12.0, 0.0, 12.0, 8.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Expanded(
                                            child: AutoSizeText(
                                              'Nice outdoor courts, solid concrete and good hoops for the neighborhood.',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
