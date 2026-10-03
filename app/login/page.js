import AuthForm from '../AuthForm';

export const metadata = { title: 'Log in · Engager' };

export default function LoginPage() {
  return <AuthForm mode="login" />;
}
