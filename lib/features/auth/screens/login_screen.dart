import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/utils/validators.dart';
import '../logic/auth_cubit.dart';
import '../logic/auth_state.dart';

/// LoginScreen: Handles user authentication via email/password or SSO.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _stayLoggedIn = true;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    context.read<AuthCubit>().login(
      _emailController.text.trim(),
      _passwordController.text,
      stayLoggedIn: _stayLoggedIn,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // No navigation here: the router's redirect sends an authenticated
        // user to /home, so this listener only surfaces messages.
        if (state is AuthResetPasswordSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Password reset email sent! Please check your inbox.',
              ),
              backgroundColor: AppColors.limeGreen,
            ),
          );
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSizes.gapHXL,

                  // Logo Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: AppColors.white,
                          size: 24,
                        ),
                      ),
                      AppSizes.gapWSm,
                      Text(
                        'StudySwap',
                        style: AppTextStyles.heading2.copyWith(fontSize: 24),
                      ),
                    ],
                  ),

                  AppSizes.gapHXXL,

                  // Welcome Text
                  Text(
                    'Welcome back',
                    style: AppTextStyles.heading1,
                    textAlign: TextAlign.center,
                  ),
                  AppSizes.gapHSm,
                  Text(
                    'Enter your details to access your account.',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),

                  AppSizes.gapHXL,

                  // SSO Login Button
                  CustomButton(
                    text: 'Log in with University SSO',
                    type: ButtonType.outline,
                    leadingWidget: const Icon(
                      Icons.school_outlined,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                    onPressed: () {
                      // Handle SSO logic
                    },
                  ),

                  AppSizes.gapHXL,

                  // Divider
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: AppColors.borderGrey),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md,
                        ),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: AppTextStyles.bodyMediumDark.copyWith(
                            color: AppColors.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: AppColors.borderGrey),
                      ),
                    ],
                  ),

                  AppSizes.gapHXL,

                  // Form Fields
                  CustomTextField(
                    label: 'Email Address',
                    hintText: 'student@university.edu',
                    prefixIcon: Icons.email_outlined,
                    controller: _emailController,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                  ),

                  AppSizes.gapHLG,

                  CustomTextField(
                    label: 'Password',
                    hintText: '........',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    controller: _passwordController,
                    validator: Validators.loginPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    autofillHints: const [AutofillHints.password],
                    topRightWidget: GestureDetector(
                      onTap: () {
                        context.read<AuthCubit>().forgotPassword(
                          _emailController.text,
                        );
                      },
                      child: Text(
                        'Forgot password?',
                        style: AppTextStyles.bodyMediumDark.copyWith(
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),

                  AppSizes.gapHMD,

                  // Stay Logged In Checkbox
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _stayLoggedIn,
                          onChanged: (value) {
                            setState(() {
                              _stayLoggedIn = value ?? false;
                            });
                          },
                          activeColor: AppColors.primaryBlue,
                          side: const BorderSide(
                            color: AppColors.solidBlack,
                            width: 2,
                          ),
                        ),
                      ),
                      AppSizes.gapWSm,
                      Text(
                        'Stay logged in',
                        style: AppTextStyles.bodyMediumDark.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  AppSizes.gapHXL,

                  // Sign In Action
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      return CustomButton(
                        text: state is AuthLoading
                            ? 'Signing In...'
                            : 'Sign In',
                        type: ButtonType.solid,
                        onPressed: state is AuthLoading ? null : _submit,
                      );
                    },
                  ),

                  AppSizes.gapHXL,

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTextStyles.bodyMediumDark,
                      ),
                      GestureDetector(
                        onTap: () => context.go('/signup'),
                        child: Text(
                          'Register here',
                          style: AppTextStyles.bodyMediumDark.copyWith(
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
