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

/// SignupScreen: Handles new user registration.
/// Based heavily on the LoginScreen design for consistency.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    context.read<AuthCubit>().signup(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // Navigation is the router's job — see AppRouter.redirect.
        if (state is AuthError) {
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
                    'Create an account',
                    style: AppTextStyles.heading1,
                    textAlign: TextAlign.center,
                  ),
                  AppSizes.gapHSm,
                  Text(
                    'Join the student-only marketplace today.',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),

                  AppSizes.gapHXL,

                  // SSO Signup Button
                  CustomButton(
                    text: 'Sign up with University SSO',
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
                    label: 'Full Name',
                    hintText: 'John Doe',
                    prefixIcon: Icons.person_outline,
                    controller: _nameController,
                    validator: Validators.fullName,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                  ),

                  AppSizes.gapHLG,

                  CustomTextField(
                    label: 'University Email',
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
                    hintText:
                        'At least ${Validators.minPasswordLength} characters',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    controller: _passwordController,
                    validator: Validators.password,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    autofillHints: const [AutofillHints.newPassword],
                  ),

                  AppSizes.gapHXL,

                  // Sign Up Action
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      return CustomButton(
                        text: state is AuthLoading
                            ? 'Creating Account...'
                            : 'Create Account',
                        type: ButtonType.solid,
                        onPressed: state is AuthLoading ? null : _submit,
                      );
                    },
                  ),

                  AppSizes.gapHXL,

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: AppTextStyles.bodyMediumDark,
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Sign in here',
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
