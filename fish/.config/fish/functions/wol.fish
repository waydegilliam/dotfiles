function wol --description "Wake Mini-Desktop via the Ubuntu Tailscale relay"
  ssh ubuntu-server-ts python3 /home/waydegilliam/development/wol.py $argv
end
