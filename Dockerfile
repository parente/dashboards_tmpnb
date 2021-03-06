# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

FROM jupyter/all-spark-notebook:8021f892543c

# Become root to do the apt-gets
USER root

RUN apt-get update && \
        apt-get install curl && \
        curl --silent --location https://deb.nodesource.com/setup_0.12 | sudo bash - && \
        apt-get install --yes nodejs npm && \
        npm install -g bower && \
        ln -s /usr/bin/nodejs /usr/bin/node

# Install library dependencies early to avoid cache busting
USER jovyan
RUN conda install seaborn futures
USER root

# Add additional config
COPY resources/jupyter_notebook_config.partial.py /tmp/
RUN cat /tmp/jupyter_notebook_config.partial.py >> /home/jovyan/.jupyter/jupyter_notebook_config.py && \
    rm /tmp/jupyter_notebook_config.partial.py

# Copy index intro
COPY resources/index.ipynb /home/jovyan/work/index.ipynb
RUN sed -i "s/{{DATE}}/$(date +'%Y-%m-%d')/g" /home/jovyan/work/index.ipynb && \
    chown jovyan /home/jovyan/work/index.ipynb

COPY resources/templates/ /srv/templates/
RUN chmod a+rX /srv/templates

# Do the remaining installs as the unprivileged notebook user
USER jovyan

ENV DASHBOARDS_VERSION 0.4.2
ENV DASHBOARDS_BUNDLERS_VERSION 0.3.1
ENV DECL_WIDGETS_VERSION 0.4.1
ENV CMS_VERSION 0.4.0

# Install incubator extensions
RUN pip install jupyter_dashboards==$DASHBOARDS_VERSION \
    jupyter_declarativewidgets==$DECL_WIDGETS_VERSION \
    jupyter_cms==$CMS_VERSION \
    jupyter_dashboards_bundlers==$DASHBOARDS_BUNDLERS_VERSION
RUN jupyter dashboards install --user --symlink && \
    jupyter declarativewidgets install --user --symlink && \
    jupyter cms install --user --symlink && \
    jupyter dashboards activate && \
    jupyter declarativewidgets activate && \
    jupyter cms activate && \
    jupyter dashboards_bundlers activate

# Add all examples
RUN cd /tmp && \
    wget -qO src.tar.gz https://github.com/jupyter-incubator/contentmanagement/archive/$CMS_VERSION.tar.gz && \
    tar xzf src.tar.gz && \
    mv contentmanagement*/etc/notebooks $HOME/work/contentmanagement && \
    find $HOME/work/contentmanagement -type f -name '*.ipynb' -print0 | xargs -0 sed -i 's/mywb\./mywb\.contentmanagement\./g' && \
    rm -rf /tmp/contentmanagement* && \
    rm -f /tmp/src.tar.gz
RUN cd /tmp && \
    wget -qO src.tar.gz https://github.com/jupyter-incubator/declarativewidgets/archive/$DECL_WIDGETS_VERSION.tar.gz && \
    tar xzf src.tar.gz && \
    mv declarativewidgets*/etc/notebooks $HOME/work/declarativewidgets && \
    rm -rf /tmp/declarativewidgets* && \
    rm -f /tmp/src.tar.gz
RUN cd /tmp && \
    wget -qO src.tar.gz https://github.com/jupyter-incubator/dashboards/archive/$DASHBOARDS_VERSION.tar.gz && \
    tar xzf src.tar.gz && \
    mv dashboards*/etc/notebooks $HOME/work/dashboards && \
    find $HOME/work/dashboards -type f -name '*.ipynb' -print0 | xargs -0 sed -i 's$/home/jovyan/work$/home/jovyan/work/dashboards$g' && \
    rm -rf /tmp/dashboards* && \
    rm -f /tmp/src.tar.gz

# Trust all notebooks
RUN find /home/jovyan/work -name '*.ipynb' -exec jupyter trust {} \;
