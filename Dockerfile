FROM dynverse/dynwrap_latest:v0.1.0

ARG GITHUB_PAT

RUN R -e 'devtools::install_github("dynverse/Mpath")'

# should be
# RUN R -e 'devtools::install_url("https://github.com/JinmiaoChenLab/Mpath/raw/master/Mpath_1.0.tar.gz")'
# but dynverse/Mpath is just so much easier to use than the tar gz above

COPY definition.yml run.R example.sh /code/

ENTRYPOINT ["/code/run.R"]
