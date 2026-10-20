import AuthForm from '../AuthForm';
import { safeNext } from '@/lib/safe-next';

export const metadata = { title: 'Sign up · Engager' };

export default async function SignupPage({ searchParams }) {
  const { next } = await searchParams;
  return <AuthForm mode="signup" next={safeNext(next)} />;
}
