FROM artembo/python-texlive:3

RUN apt-get update && apt-get install -y luarocks
RUN pip install Sphinx==2.2.0 sphinx_rtd_theme awscli
RUN luarocks install penlight
ADD https://api.github.com/repos/artembo/LDoc/git/refs/heads/rst version.json
RUN git clone -b rst https://github.com/artembo/LDoc.git /usr/local/ldoc

COPY . /app
WORKDIR /app

RUN lua /usr/local/ldoc/ldoc.lua --ext=rst --dir=configs --all .

COPY configs /app/configs
RUN cd configs && sphinx-build -n -b json -d tracing/_build_en/doctrees . tracing/_build_en/json
