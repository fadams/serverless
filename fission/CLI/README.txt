Install the Fission CLI
https://docs.fission.io/installation/#install-the-fission-cli

curl -Lo fission https://github.com/fission/fission/releases/download/1.0.0/fission-cli-linux && chmod +x fission 


Either add to PATH directly or add to .bashrc

or if, like me, you already have a $HOME/bin directory for local executables
then either symlink to the faas-cli or copy to $HOME/bin


TODO
Create Dockerised install of CLI to avoid any accidental installing to /usr/local/bin


