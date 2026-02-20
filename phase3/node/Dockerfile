FROM node
COPY ./app /app
WORKDIR /app
RUN npm install 
EXPOSE 3000
VOLUME /app/public/uploads
CMD ["node","main.js"]