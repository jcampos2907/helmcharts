pipeline {
  agent any

  environment {
    HELM_VERSION       = "3.15.0"

    // 🧩 CHANGE THESE TO YOUR REAL VALUES:
    CHARTS_REPO_OWNER  = "jcampos2907"       // e.g. "jcampos2907"
    CHARTS_REPO_NAME   = "githubPages"                   // repo that will host index.yaml + .tgz
    CHARTS_REPO_BRANCH = "main"                          // or "gh-pages" if you use that
  }

  stages {
           stage('Checkout') {
            steps {
                retry(3) {
                    checkout scm
                }
            }
        }
    // stage('Checkout source') {
    //   steps {
    //     checkout scm
    //   }
    // }

    stage('Install Helm') {
      steps {
        sh '''
          curl -sSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar xz
          sudo mv linux-amd64/helm /usr/local/bin/helm
          helm version
        '''
      }
    }

    stage('Package Helm charts') {
      steps {
        sh '''
          mkdir -p dist

          # find nested Chart.yaml, eg: pihole/newchart, eventos-backend/something
          find . -mindepth 2 -maxdepth 5 -name Chart.yaml -print | while read chart; do
            chart_dir=$(dirname "$chart")
            echo "==> Packaging chart at $chart_dir"
            helm lint "$chart_dir"
            helm package "$chart_dir" --destination dist
          done

          echo "Packaged charts:"
          ls -l dist
        '''
      }
    }

    stage('Publish to githubPages repo') {
      steps {
        withCredentials([string(credentialsId: 'github-pat', variable: 'GH_PAT')]) {
          sh '''
            git config --global user.name  "jenkins"
            git config --global user.email "jenkins@local"

            CHARTS_REPO_URL="https://${GH_PAT}@github.com/${CHARTS_REPO_OWNER}/${CHARTS_REPO_NAME}.git"

            rm -rf gh-pages-repo
            git clone "$CHARTS_REPO_URL" gh-pages-repo

            mkdir -p gh-pages-repo/charts
            cp dist/*.tgz gh-pages-repo/charts/

            cd gh-pages-repo

            # regenerate/merge index.yaml
            if [ -f charts/index.yaml ]; then
              helm repo index charts \
                --url "https://${CHARTS_REPO_OWNER}.github.io/${CHARTS_REPO_NAME}/charts" \
                --merge charts/index.yaml
            else
              helm repo index charts \
                --url "https://${CHARTS_REPO_OWNER}.github.io/${CHARTS_REPO_NAME}/charts"
            fi

            git add charts
            git commit -m "Update Helm charts from ${JOB_NAME}@${BUILD_NUMBER}" || echo "No changes to commit"
            git push origin ${CHARTS_REPO_BRANCH}
          '''
        }
      }
    }
  }
}
