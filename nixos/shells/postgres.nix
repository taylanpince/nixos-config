{ pkgs }:

{
  postgres = pkgs.mkShell {
    name = "postgres";
    packages = with pkgs; [
      postgresql_16
    ];

    shellHook = ''
      export PGDATA="$PWD/.pgdata"
      if [ ! -d "$PGDATA" ]; then
        initdb --no-locale --encoding=UTF8
        echo "listen_addresses = '127.0.0.1'" >> "$PGDATA/postgresql.conf"
        echo "unix_socket_directories = '$PGDATA'" >> "$PGDATA/postgresql.conf"
      fi
      pg_ctl start -l "$PGDATA/log"
      trap "pg_ctl stop" EXIT
    '';
  };
}
