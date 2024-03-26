# Use Amazon's AWS CLI Docker image as the base
FROM cimg/aws:2024.03

# Install Node.js
# RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# RUN . ~/.nvm/nvm.sh
# RUN nvm install 20
# RUN yum install nodejs20
# RUN yum install -y gcc-c++ make
# RUN curl -sL https://rpm.nodesource.com/setup_6.x | sudo -E bash -
# RUN yum install -y nodejs

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY package*.json ./

RUN npm ci
# If you are building your code for production
# RUN npm ci --only=production

# Bundle app source
COPY index.js ./

# Your app binds to port 8080 so you'll use the EXPOSE instruction to have it mapped by the docker daemon
EXPOSE 8080

CMD [ "node", "index.js" ]