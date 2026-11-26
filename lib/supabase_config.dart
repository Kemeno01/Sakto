const supabaseUrl = 'https://lpsbyblsyaigqdgxnhyn.supabase.co';
const supabaseAnonKey = 'sb_publishable_dzZX-laE891T-FYn0jTtdw_5QG7iUvU';

const authRedirect = 'io.sakto.app://login-callback';

bool get supabaseReady => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
