import '/auth/firebase_auth/auth_util.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'create_account_model.dart';
import 'package:go_router/go_router.dart';
import '/utils/responsive_utils.dart';
export 'create_account_model.dart';

class CreateAccountWidget extends StatefulWidget {
  const CreateAccountWidget({super.key});

  @override
  State<CreateAccountWidget> createState() => _CreateAccountWidgetState();
}

class _CreateAccountWidgetState extends State<CreateAccountWidget> {
  late CreateAccountModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  void safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _model = CreateAccountModel();

    _model.emailAddressTextController ??= TextEditingController();
    _model.emailAddressFocusNode ??= FocusNode();

    _model.passwordTextController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();

    _model.passwordConfirmTextController ??= TextEditingController();
    _model.passwordConfirmFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
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
        backgroundColor: Theme.of(context).colorScheme.background,
        body: SafeArea(
          top: true,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                flex: 8,
                child: Container(
                  width: 100.0,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.background,
                  ),
                  alignment: AlignmentDirectional(0.0, -1.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 140.0,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.background,
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
                                32.0, 0.0, 0.0, 0.0),
                            child: Text(
                              'brand.ai',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create an account',
                                  style: Theme.of(context).textTheme.displaySmall,
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
                                    width: 370.0,
                                    child: TextFormField(
                                      controller:
                                          _model.emailAddressTextController,
                                      focusNode: _model.emailAddressFocusNode,
                                      autofocus: true,
                                      autofillHints: [AutofillHints.email],
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        labelStyle: Theme.of(context).textTheme.labelMedium,
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.surface,
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
                                        fillColor: Theme.of(context).colorScheme.surface,
                                      ),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _model
                                          .emailAddressTextControllerValidator,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 16.0),
                                  child: Container(
                                    width: 370.0,
                                    child: TextFormField(
                                      controller: _model.passwordTextController,
                                      focusNode: _model.passwordFocusNode,
                                      autofocus: true,
                                      autofillHints: [AutofillHints.password],
                                      obscureText: !_model.passwordVisibility,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        labelStyle: Theme.of(context).textTheme.labelMedium,
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.surface,
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
                                        fillColor: Theme.of(context).colorScheme.surface,
                                        suffixIcon: InkWell(
                                          onTap: () => safeSetState(
                                            () => _model.passwordVisibility =
                                                !_model.passwordVisibility,
                                          ),
                                          focusNode:
                                              FocusNode(skipTraversal: true),
                                          child: Icon(
                                            _model.passwordVisibility
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Theme.of(context).colorScheme.secondary,
                                            size: 24.0,
                                          ),
                                        ),
                                      ),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      validator: _model
                                          .passwordTextControllerValidator,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 16.0),
                                  child: Container(
                                    width: 370.0,
                                    child: TextFormField(
                                      controller:
                                          _model.passwordConfirmTextController,
                                      focusNode:
                                          _model.passwordConfirmFocusNode,
                                      autofocus: true,
                                      autofillHints: [AutofillHints.password],
                                      obscureText:
                                          !_model.passwordConfirmVisibility,
                                      decoration: InputDecoration(
                                        labelText: 'Confirm Password',
                                        labelStyle: Theme.of(context).textTheme.labelMedium,
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.surface,
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
                                        fillColor: Theme.of(context).colorScheme.surface,
                                        suffixIcon: InkWell(
                                          onTap: () => safeSetState(
                                            () => _model
                                                    .passwordConfirmVisibility =
                                                !_model
                                                    .passwordConfirmVisibility,
                                          ),
                                          focusNode:
                                              FocusNode(skipTraversal: true),
                                          child: Icon(
                                            _model.passwordConfirmVisibility
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Theme.of(context).colorScheme.secondary,
                                            size: 24.0,
                                          ),
                                        ),
                                      ),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      minLines: 1,
                                      validator: _model
                                          .passwordConfirmTextControllerValidator,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 16.0),
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      if (_model.passwordTextController?.text !=
                                          _model.passwordConfirmTextController
                                              ?.text) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Passwords don\'t match!',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final user = await authManager
                                          .createAccountWithEmail(
                                        context,
                                        _model.emailAddressTextController?.text ?? '',
                                        _model.passwordTextController?.text ?? '',
                                      );
                                      if (user == null) {
                                        return;
                                      }

                                      context.go('/create-goals');
                                    },
                                    child: Text('Create Account'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size(370.0, 44.0),
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 0.0, 0.0, 0.0),
                                      textStyle: Theme.of(context).textTheme.titleSmall,
                                      elevation: 3.0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                    ),
                                  ),
                                ),

                                // You will have to add an action on this rich text to go to your login page.
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 12.0, 0.0, 12.0),
                                  child: RichText(
                                    textScaler:
                                        MediaQuery.of(context).textScaler,
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Already have an account? ',
                                          style: TextStyle(),
                                        ),
                                        TextSpan(
                                          text: 'Sign In here',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                          mouseCursor: SystemMouseCursors.click,
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () async {
                                              context
                                                  .pushNamed('Authentication');
                                            },
                                        )
                                      ],
                                      style: Theme.of(context).textTheme.labelLarge,
                                    ),
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
              if (responsiveVisibility(
                context: context,
                phone: false,
                tablet: false,
              ))
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Container(
                      width: 100.0,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.background,
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: CachedNetworkImageProvider(
                            'https://images.unsplash.com/photo-1514924013411-cbf25faa35bb?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1380&q=80',
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16.0),
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
